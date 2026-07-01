// Globals
import {
  inner_computeFrame_WASM,
  getWasm,
  setupWasm,
} from './main.js';


// Init Wasm VM
const URL = new URLSearchParams(self.location.search);

let wasmFile = "";
if (URL.has('wasm-ref') || URL.has('Wasm-ref')|| URL.has('WASM-ref')) wasmFile = "main_ref.wasm";
else if (URL.has('wasm-vec') || URL.has('Wasm-vec')|| URL.has('WASM-vec')) wasmFile = "main_vec.wasm";
else if (URL.has('wasm-opt') || URL.has('Wasm-opt')|| URL.has('WASM-opt')) wasmFile = "main_opt.wasm";
else throw new Error("No Wasm version detected!");

console.log("Wasm version :", wasmFile);
const [ memory, fnWasm ] = await getWasm(wasmFile);


// Computations
self.onmessage = function(initArgs) {

  // Setup Wasm VM
  const { kernel, width, height, img1len, img2len } = initArgs.data;
  const [ ptrKernelEdge, ptrKernelSharp, ptrInput, wasmInputData, ptrOutput, wasmOutputData ] = setupWasm(memory, width, height, img1len, img2len);

  let kernelWASM;
  if (kernel === "edgeDetect") kernelWASM = ptrKernelEdge;
  else if (kernel === "sharpen") kernelWASM = ptrKernelSharp;
  else throw new Error("Unknown kernel!");

  // Main of onmessage
  self.onmessage = function(frameEvent) {
    const { width, height, inputData, outputData } = frameEvent.data;

    inner_computeFrame_WASM(
      width,
      height,
      kernelWASM,
      ptrInput,
      wasmInputData,
      inputData,
      ptrOutput,
      wasmOutputData,
      outputData,
      fnWasm
    );

    self.postMessage({ outputData }, [outputData.buffer]);
  };

};
