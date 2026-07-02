// Globals
let video;
let c1, c2, c3;
let ctx1, ctx2, ctx3;
let reductionFactor = 1.5;

import {
  kernels,
  setupWasm,
} from './main.js';


// Load function
export function init_demo(kernel) {

  video = document.getElementById("video");
  c1 = document.getElementById("c1");
  ctx1 = c1.getContext("2d", { willReadFrequently: true });
  c2 = document.getElementById("c2");
  ctx2 = c2.getContext("2d");
  c3 = document.getElementById("c3");
  ctx3 = c3.getContext("2d");

  let kernelJS;
  if (kernel === "edgeDetect") kernelJS = kernels.edgeDetect;
  else if (kernel === "sharpen") kernelJS = kernels.sharpen;
  else throw new Error("Unknown kernel!");

  const jsWorker = new Worker('./js_worker.js', { type: 'module' });
  const wasmWorker = new Worker(`./wasm_worker.js${window.location.search}`, { type: 'module' });

  video.addEventListener("play", function() {

    const width = Math.max(640, Math.floor(video.videoWidth / reductionFactor));
    const height = Math.max(400, Math.floor(video.videoHeight / reductionFactor));

    c1.width = width;
    c2.width = width;
    c3.width = width;
    c1.height = height;
    c2.height = height;
    c3.height = height;

    wasmWorker.postMessage({
      kernel,
      width,
      height,
      img1len : ctx1.getImageData(0, 0, width, height).data.length,
      img2len : ctx3.createImageData(width, height).data.length,
    });

    let jsWorkerBusy = false;
    let wasmWorkerBusy = false;

    jsWorker.onmessage = function(e) {
      const { outputData } = e.data;
      const imgData = new ImageData(outputData, c2.width, c2.height);
      ctx2.putImageData(imgData, 0, 0);
      jsWorkerBusy = false;
    };

    wasmWorker.onmessage = function(e) {
      const { outputData } = e.data;
      const imgData = new ImageData(outputData, c3.width, c3.height);
      ctx3.putImageData(imgData, 0, 0);
      wasmWorkerBusy = false;
    };

    function renderLoop() {
      if (!(video.paused || video.ended)) {

        ctx1.drawImage(video, 0, 0, width, height);
        const inputData = ctx1.getImageData(0, 0, width, height).data;

        if (!jsWorkerBusy) {

          jsWorkerBusy = true;
          const jsBuffer = new Uint8ClampedArray(inputData).buffer;
          const outputData = ctx2.createImageData(width, height).data;

          jsWorker.postMessage({
            width,
            height,
            kernelJS,
            inputData,
            outputData,
          }, [jsBuffer]);

        }

        if (!wasmWorkerBusy) {

          wasmWorkerBusy = true;
          const wasmBuffer = new Uint8ClampedArray(inputData).buffer;
          const outputData = ctx3.createImageData(width, height).data;

          wasmWorker.postMessage({
            width,
            height,
            inputData,
            outputData,
          }, [wasmBuffer]);

        }

        requestAnimationFrame(renderLoop);
      }
    }

    requestAnimationFrame(renderLoop);

  });

}


// Main function
export async function main_demo(kernel) {

  const URL = new URLSearchParams(self.location.search);


  if (URL.has('reductionFactor')) {

    const parsedFactor = parseFloat(URL.get('reductionFactor'));

    if (!isNaN(parsedFactor) && parsedFactor >= 1) {
      reductionFactor = parsedFactor;
    }

  }
  console.log("Reduction factor =", reductionFactor);


  init_demo(kernel);

}
