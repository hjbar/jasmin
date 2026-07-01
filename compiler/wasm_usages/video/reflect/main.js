// Globals
let video;
let c1, c2;
let ctx1, ctx2;
const reflection = 3;


// Init function
function init(setup) {

  video = document.getElementById("video");
  c1 = document.getElementById("c1");
  ctx1 = c1.getContext("2d");
  c2 = document.getElementById("c2");
  ctx2 = c2.getContext("2d");

  video.addEventListener("play", function() {
    const height = Math.min(256, video.height / reflection);

    c1.width = video.width;
    c1.height = height;
    c2.width = video.width;
    c2.height = height;

    const computeStrategy = setup(ctx1.getImageData(0, 0, c1.width, c1.height).data.length);

    function loop() {
      if (!(video.paused || video.ended)) {
        computeFrame(computeStrategy);
        setTimeout(loop, 0);
      }
    }

    loop();
  });

}


// AlphaRow function
function alphaRow_JS(data, width, j, a) {

  for (let i = 0; i < (j + width); i++) {
    const index = 3 + (4 * (i + (width * j)));
    data[index] = a;
  }

}


// Inner_computeFrame_JS function
function inner_computeFrame_JS(data, width, height, step) {

  for (let j = 0; j < height; j++) {
    const alpha = Math.max(0, 256 - (step * j));
    alphaRow_JS(data, width, j, alpha);
  }

}


// ComputeFrame function
function computeFrame(computeStrategy) {

  ctx1.save();
  ctx1.setTransform(1, 0, 0, -1, 0, video.height);
  ctx1.drawImage(video, 0, 0, video.width, video.height);
  ctx1.restore();

  const frame = ctx1.getImageData(0, 0, c1.width, c1.height);
  const data = frame.data;
  const step = Math.round(256 / c1.height);

  computeStrategy(data, video.width, c1.height, step);

  ctx2.putImageData(frame, 0, 0);

}


// JS wrapper for Wasm inner_computeFrame
function inner_computeFrame_WASM(data, width, height, step, fnWasm, ptrData, wasmData) {

  wasmData.set(data);

  fnWasm(ptrData, width, height, step);

  data.set(wasmData);

}


// Init wasmVM
async function getWasm(path) {

  const memory = new WebAssembly.Memory({ initial: 1024 });
  const importObject = { env: { memory } };
  const { instance } = await WebAssembly.instantiateStreaming(fetch("main_ref.wasm"), importObject);

  const fnWasm = instance.exports.inner_computeFrame;
  const buffer = memory.buffer;

  return [ fnWasm, buffer ];

}


// Main function
async function main() {

  const URL = new URLSearchParams(window.location.search);

  if (URL.has('wasm-ref') || URL.has('Wasm-ref')|| URL.has('WASM-ref')) {

    console.log("WASM-ref");
    const [ fnWasm, buffer ] = await getWasm("main_ref.wasm");

    const setup = (dataLength) => {
      const ptrData = 50000;
      const wasmData = new Uint8ClampedArray(buffer, ptrData, dataLength);

      const compute = (data, width, height, step) => {
        inner_computeFrame_WASM(data, width, height, step, fnWasm, ptrData, wasmData);
      };

      return compute;
    };

    init(setup);

  } else if (URL.has('wasm-vec') || URL.has('Wasm-vec')|| URL.has('WASM-vec')) {

    console.log("WASM-vec");
    const [ fnWasm, buffer ] = await getWasm("main_vec.wasm");

    const setup = (dataLength) => {
      const ptrData = 50000;
      const wasmData = new Uint8ClampedArray(buffer, ptrData, dataLength);

      const compute = (data, width, height, step) => {
        inner_computeFrame_WASM(data, width, height, step, fnWasm, ptrData, wasmData);
      };

      return compute;
    };

    init(setup);

  } else if (URL.has('wasm-opt') || URL.has('Wasm-opt')|| URL.has('WASM-opt')) {

    console.log("WASM-opt");
    const [ fnWasm, buffer ] = await getWasm("main_opt.wasm");

    const setup = (dataLength) => {
      const ptrData = 50000;
      const wasmData = new Uint8ClampedArray(buffer, ptrData, dataLength);

      const compute = (data, width, height, step) => {
        inner_computeFrame_WASM(data, width, height, step, fnWasm, ptrData, wasmData);
      };

      return compute;
    };

    init(setup);

   } else if (URL.has('js') || URL.has('Js') || URL.has('JS')) {

    console.log("JS");

    const setup = (dataLength) => {
      const compute = (data, width, height, step) => {
        inner_computeFrame_JS(data, width, height, step);
      }

      return compute;
    };

    init(setup);

  } else {

    console.log("ERROR");

  }

}


// Compute init during the load
window.addEventListener("load", main);
