// Globals
let video;
let c1, c2, c3;
let ctx1, ctx2, ctx3;
var reductionFactor = 3;


// Convulution matrices (kernels)
export const kernels = {
  sharpen: [
     0, -1,  0,
    -1,  5, -1,
     0, -1,  0
  ],
  edgeDetect: [
    -1, -1, -1,
    -1,  8, -1,
    -1, -1, -1
  ]
};


// Load function
function init(setup) {

  video = document.getElementById("video");
  c1 = document.getElementById("c1");
  ctx1 = c1.getContext("2d");
  c2 = document.getElementById("c2");
  ctx2 = c2.getContext("2d");
  c3 = document.getElementById("c3");
  ctx3 = c3.getContext("2d");

  video.addEventListener("play", function() {

    const width = Math.max(640, Math.floor(video.videoWidth / reductionFactor));
    const height = Math.max(400, Math.floor(video.videoHeight / reductionFactor));

    c1.width = width;
    c2.width = width;
    c3.width = width;
    c1.height = height;
    c2.height = height;
    c3.height = height;

    const [ computeStrategy1, computeStrategy2 ] = setup(c1, ctx1, ctx2);

    function loop() {
      if (!(video.paused || video.ended)) {
        computeFrame(computeStrategy1, computeStrategy2);
        setTimeout(loop, 0);
      }
    }

    loop();

  });

}


// Inner_computeFrame JS function
export function inner_computeFrame_JS(width, height, kernel, inputData, outputData) {

  for (let j = 1; j < height - 1; j++) {
    for (let i = 1; i < width - 1; i++) {

      let r = 0;
      let g = 0;
      let b = 0;

      for (let y = -1; y <= 1; y++) {
        for (let x = -1; x <= 1; x++) {

          const idx = ((j + y) * width + (i + x)) * 4;
          const kernelIdx = (y + 1) * 3 + (x + 1);
          const weight = kernel[kernelIdx];

          r += inputData[idx + 0] * weight;
          g += inputData[idx + 1] * weight;
          b += inputData[idx + 2] * weight;

        }
      }

      const idx = (j * width + i) * 4;

      outputData[idx + 0] = Math.min(Math.max(r, 0), 255);
      outputData[idx + 1] = Math.min(Math.max(g, 0), 255);
      outputData[idx + 2] = Math.min(Math.max(b, 0), 255);
      outputData[idx + 3] = 255;

    }
  }

}



// ComputeFrame function
function computeFrame(computeStrategy1, computeStrategy2) {

  const width = c1.width;
  const height = c1.height;

  ctx1.drawImage(video, 0, 0, width, height);

  const inputFrame = ctx1.getImageData(0, 0, width, height);
  const inputData = inputFrame.data;

  const outputFrameEdge = ctx2.createImageData(width, height);
  const outputDataEdge = outputFrameEdge.data;

  const outputFrameSharp = ctx3.createImageData(width, height);
  const outputDataSharp = outputFrameSharp.data;

  computeStrategy1(width, height, inputData, outputDataEdge );
  computeStrategy2(width, height, inputData, outputDataSharp);

  ctx2.putImageData(outputFrameEdge, 0, 0);
  ctx3.putImageData(outputFrameSharp, 0, 0);

}


// JS wrapper for Wasm inner_computeFrame
export function inner_computeFrame_WASM(width, height, ptrKernel, ptrInput, wasmInputData, inputData, ptrOutput, wasmOutputData, outputData, fnWasm) {

  wasmInputData.set(inputData);

  fnWasm(
    width,
    height,
    ptrKernel,
    ptrInput,
    ptrOutput
  );

  outputData.set(wasmOutputData);

}


// Init wasmVM
export async function getWasm(path) {

  // Init Wasm
  const memory = new WebAssembly.Memory({ initial: 1024 });
  const importObject = { env: { memory } };
  const { instance } = await WebAssembly.instantiateStreaming(fetch(path), importObject);

  // Return
  return [ memory, instance.exports.inner_computeFrame ];

}


// Write data in Wasm
export function setupWasm(memory, width, height, img1len, img2len) {

  // Wasm memory
  const buffer = memory.buffer;

  // Kernels
  const kernelEdge = kernels.edgeDetect;
  const kernelEdgeLength = kernelEdge.length * 4;

  const kernelSharp = kernels.sharpen;
  const kernelSharpLength = kernelSharp.length * 4;

  // Input/output
  const inputLength = img1len;
  const outputLength = img2len;

  // Ptr
  const ptrKernelEdge = 50000;
  const ptrKernelSharp = ptrKernelEdge + kernelEdgeLength;
  const ptrInput = ptrKernelSharp + kernelSharpLength;
  const ptrOutput = ptrInput + inputLength;

  // Copy kernels
  const wasmKernelEdge = new Int32Array(buffer, ptrKernelEdge, kernelEdgeLength);
  wasmKernelEdge.set(kernelEdge);

  const wasmKernelSharp = new Int32Array(buffer, ptrKernelSharp, kernelSharpLength);
  wasmKernelSharp.set(kernelSharp);

  // Init input/output buffers
  const wasmInputData = new Uint8ClampedArray(buffer, ptrInput, inputLength);
  const wasmOutputData = new Uint8ClampedArray(buffer, ptrOutput, outputLength);

  // Return
  return [ ptrKernelEdge, ptrKernelSharp, ptrInput, wasmInputData, ptrOutput, wasmOutputData ];

}


// Main function
async function main() {

  const URL = new URLSearchParams(window.location.search);

  if (URL.has('reductionFactor')) {

    const parsedFactor = parseFloat(URL.get('reductionFactor'));

    if (!isNaN(parsedFactor) && parsedFactor >= 1) {
      reductionFactor = parsedFactor;
    }

  }
  console.log("Reduction factor =", reductionFactor);

  if (URL.has('wasm-ref') || URL.has('Wasm-ref')|| URL.has('WASM-ref')) {

    console.log("WASM-ref");
    const [ memory, fnWasm ] = await getWasm("main_ref.wasm");

    const setup = (c1, ctx1, ctx2) => {
      const width = c1.width;
      const height = c1.height;
      const img1len = ctx1.getImageData(0, 0, width, height).data.length;
      const img2len = ctx2.createImageData(width, height).data.length;
      const [ ptrKernelEdge, ptrKernelSharp, ptrInput, wasmInputData, ptrOutput, wasmOutputData ] = setupWasm(memory, width, height, img1len, img2len);

      const f1 = (width, height, inputData, outputData) => {
        inner_computeFrame_WASM(width, height, ptrKernelEdge, ptrInput, wasmInputData, inputData, ptrOutput, wasmOutputData, outputData, fnWasm)
      };
      const f2 = (width, height, inputData, outputData) => {
        inner_computeFrame_WASM(width, height, ptrKernelSharp, ptrInput, wasmInputData, inputData, ptrOutput, wasmOutputData, outputData, fnWasm)
      };

      return [ f1, f2 ];
    };

    init(setup);

  } else if (URL.has('wasm-vec') || URL.has('Wasm-vec')|| URL.has('WASM-vec')) {

    console.log("WASM-vec");
    const [ memory, fnWasm ] = await getWasm("main_vec.wasm");

    const setup = (c1, ctx1, ctx2) => {
      const width = c1.width;
      const height = c1.height;
      const img1len = ctx1.getImageData(0, 0, width, height).data.length;
      const img2len = ctx2.createImageData(width, height).data.length;
      const [ ptrKernelEdge, ptrKernelSharp, ptrInput, wasmInputData, ptrOutput, wasmOutputData ] = setupWasm(memory, width, height, img1len, img2len);

      const f1 = (width, height, inputData, outputData) => {
        inner_computeFrame_WASM(width, height, ptrKernelEdge, ptrInput, wasmInputData, inputData, ptrOutput, wasmOutputData, outputData, fnWasm)
      };
      const f2 = (width, height, inputData, outputData) => {
        inner_computeFrame_WASM(width, height, ptrKernelSharp, ptrInput, wasmInputData, inputData, ptrOutput, wasmOutputData, outputData, fnWasm)
      };

      return [ f1, f2 ];
    };

    init(setup);

  } else if (URL.has('wasm-opt') || URL.has('Wasm-opt')|| URL.has('WASM-opt')) {

    console.log("WASM-opt");
    const [ memory, fnWasm ] = await getWasm("main_opt.wasm");

    const setup = (c1, ctx1, ctx2) => {
      const width = c1.width;
      const height = c1.height;
      const img1len = ctx1.getImageData(0, 0, width, height).data.length;
      const img2len = ctx2.createImageData(width, height).data.length;
      const [ ptrKernelEdge, ptrKernelSharp, ptrInput, wasmInputData, ptrOutput, wasmOutputData ] = setupWasm(memory, width, height, img1len, img2len);

      const f1 = (width, height, inputData, outputData) => {
        inner_computeFrame_WASM(width, height, ptrKernelEdge, ptrInput, wasmInputData, inputData, ptrOutput, wasmOutputData, outputData, fnWasm)
      };
      const f2 = (width, height, inputData, outputData) => {
        inner_computeFrame_WASM(width, height, ptrKernelSharp, ptrInput, wasmInputData, inputData, ptrOutput, wasmOutputData, outputData, fnWasm)
      };

      return [ f1, f2 ];
    };

    init(setup);

  } else if (URL.has('js') || URL.has('Js') || URL.has('JS')) {

    console.log("JS");

    const setup = (c1, ctx1, ctx2) => {
      const f1 = (width, height, inputData, outputData) => {
        inner_computeFrame_JS(width, height, kernels.edgeDetect, inputData, outputData);
      };
      const f2 = (width, height, inputData, outputData) => {
        inner_computeFrame_JS(width, height, kernels.sharpen, inputData, outputData);
      }

      return [ f1, f2 ];
    };

    init(setup);

  } else {

    console.log("ERROR");

  }

}


// Compute init during the load
globalThis.addEventListener("load", () => {
  if (!globalThis.location.pathname.includes('demo')) {
    main();
  }
});
