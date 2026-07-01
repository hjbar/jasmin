// Libraries
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const { performance } = require('perf_hooks');


// FFmpeg setup
const ffmpeg = require('fluent-ffmpeg');
const ffmpegInstaller = require('@ffmpeg-installer/ffmpeg');
ffmpeg.setFfmpegPath(ffmpegInstaller.path);


// To make a link with the web part of the code
const browserMock = {
  console: console,
  window: { addEventListener: () => {} },
  document: { getElementById: () => ({ addEventListener: () => {} }) },
  URLSearchParams: class { has() { return false; } },
  WebAssembly: WebAssembly,
  addEventListener: () => {},
};


// Virtual Machine to make the connection with the web part of the code
const context = vm.createContext(browserMock);


// Read the main file
try {
  let mainJsCode = fs.readFileSync('./main.js', 'utf8');

  mainJsCode = mainJsCode
    .replace(/export\s+const\s+/g, 'var ')
    .replace(/export\s+function\s+/g, 'function ')
    .replace(/export\s+async\s+function\s+/g, 'async function ');

  vm.runInContext(mainJsCode, context);
} catch (err) {
  console.error("Impossible to read main.js :", err);
  process.exit(1);
}


// Get the wanted functions of main.js
const { reductionFactor, kernels, inner_computeFrame_JS, inner_computeFrame_WASM, setupWasm } = context;


// Init the Wasm module with the Node stuff
async function initWasm(path, width, height, frameSize) {

  const wasmBuffer = fs.readFileSync(path);
  const memory = new WebAssembly.Memory({ initial: 1024 });
  const importObject = { env: { memory } };

  const { instance } = await WebAssembly.instantiate(wasmBuffer, importObject);
  const fnWasm = instance.exports.inner_computeFrame;

  const [ ptrKernelEdge, ptrKernelSharp, ptrInput, wasmInputData, ptrOutput, wasmOutputData ] = setupWasm(memory, width, height, frameSize, frameSize);

  const f1 = (width, height, inputData, outputData) => {
    inner_computeFrame_WASM(width, height, ptrKernelEdge, ptrInput, wasmInputData, inputData, ptrOutput, wasmOutputData, outputData, fnWasm)
  };
  const f2 = (width, height, inputData, outputData) => {
    inner_computeFrame_WASM(width, height, ptrKernelSharp, ptrInput, wasmInputData, inputData, ptrOutput, wasmOutputData, outputData, fnWasm)
  };
  return [ f1, f2 ];

}


// Init the JS functions
function initJS() {

  const f1 = (width, height, inputData, outputData) => {
    inner_computeFrame_JS(width, height, kernels.edgeDetect, inputData, outputData);
  };
  const f2 = (width, height, inputData, outputData) => {
    inner_computeFrame_JS(width, height, kernels.sharpen, inputData, outputData);
  };
  return [ f1, f2 ];

}


// Extract data from the video
function extractFramesFromVideo(videoPath) {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(videoPath, (err, metadata) => {

      if (err) return reject(err);

      const videoStream = metadata.streams.find(s => s.codec_type === 'video');
      if (!videoStream) return reject(new Error("No video found."));

      const originalWidth = videoStream.width;
      const originalHeight = videoStream.height;

      const width = Math.max(640, Math.floor(originalWidth / reductionFactor));
      const height = Math.max(400, Math.floor(originalHeight / reductionFactor));

      const frameSize = width * height * 4;

      const frames = [];
      let currentBuffer = Buffer.alloc(0);

      console.log(`[FFmpeg] Original video: ${originalWidth}x${originalHeight} -> New video: ${width}x${height}`);

      ffmpeg(videoPath)
        .size(`${width}x${height}`)
        .outputFormat('rawvideo')
        .outputOptions('-pix_fmt rgba')
        .on('error', (ffmpegErr) => reject(ffmpegErr))
        .on('end', () => {
          console.log(`[FFmpeg] ${frames.length} frames computed.`);
          resolve({ width, height, frameSize, frames });
        })
        .pipe()
        .on('data', (chunk) => {
          currentBuffer = Buffer.concat([currentBuffer, chunk]);

          while (currentBuffer.length >= frameSize) {
            const frameBuffer = currentBuffer.subarray(0, frameSize);
            frames.push(new Uint8ClampedArray(frameBuffer));
            currentBuffer = currentBuffer.subarray(frameSize);
          }
        });

    });
  });
}


// Benchmark function
function runBenchmark(label, computeStrategy1, computeStrategy2, width, height, frames, samples, iterations) {

  // Warmup
  const warmupInputData = new Uint8ClampedArray(frames[0]);
  const warmupDataEdge = new Uint8ClampedArray(frames[0].length);
  const warmupDataSharp = new Uint8ClampedArray(frames[0].length);

  for (let k = 0; k < (iterations * 0.2); k++) {
    computeStrategy1(width, height, warmupInputData, warmupDataEdge);
    computeStrategy2(width, height, warmupInputData, warmupDataSharp);
  }

  // Benchmark
  const framesCopy = frames.map(f => new Uint8ClampedArray(f))
  const framesCopyEdge = frames.map(f => new Uint8ClampedArray(f.length))
  const framesCopySharp = frames.map(f => new Uint8ClampedArray(f.length))
  let totalTime = 0;

  for (let j = 0; j < samples; j++) {
    for (let i = 0; i < iterations; i++) {

    const frameIndex = i % framesCopy.length;
    const framesCopy_i = framesCopy[frameIndex];
    const framesCopyEdge_i = framesCopyEdge[frameIndex];
    const framesCopySharp_i = framesCopySharp[frameIndex];

    const start = performance.now();
    computeStrategy1(width, height, framesCopy_i, framesCopyEdge_i);
    computeStrategy2(width, height, framesCopy_i, framesCopySharp_i);
    const end = performance.now();

    totalTime += end - start;

    }
  }

  // Compute results
  totalTime /= samples;
  const avgTime = totalTime / iterations;

  // Print results
  console.log(`\n=== [${label}] ===\n`);
  console.log(`    Total time  : ${(totalTime / 1000).toFixed(2)} s`);
  console.log(`    Avg / frame : ${avgTime.toFixed(4)} ms\n`);

  return [ totalTime, avgTime, framesCopyEdge, framesCopySharp ];

}


// Main function
async function main() {

  // Parse command line
  const videoArg = process.argv[2];
  if (!videoArg) {
    console.error("Error : no video passed.\nUsage : node benchmark.js video.mp4 samples iterations");
    process.exit(1);
  }

  const videoPath = path.resolve(videoArg);
  if (!fs.existsSync(videoPath)) {
    console.error(`Error : the video file don't exists (${videoPath})`);
    process.exit(1);
  }

  const SAMPLES = parseInt(process.argv[3], 10);
  const ITERATIONS_JS = parseInt(process.argv[4], 10);
  const ITERATIONS_WASM = parseInt(process.argv[5], 10);

  // Init params
  const { width, height, frameSize, frames } = await extractFramesFromVideo(videoPath);
  if (frames.length === 0) {
    console.error("Error: no frame computed from the video.");
    process.exit(1);
  }

  const [ f1_JS, f2_JS ] = initJS();
  const [ f1_WASM_ref, f2_WASM_ref ] = await initWasm('./main_ref.wasm', width, height, frameSize);
  const [ f1_WASM_vec, f2_WASM_vec ] = await initWasm('./main_vec.wasm', width, height, frameSize);
  const [ f1_WASM_opt, f2_WASM_opt ] = await initWasm('./main_opt.wasm', width, height, frameSize);

  // Start the benchmark
  console.log(`\n\nBenchmark (${width}x${height} video dimensions, ${SAMPLES} samples, ${ITERATIONS_JS} iterations for JS and ${ITERATIONS_WASM} iterations for WASM)...\n`);

  const [ jsTotal, jsAvg, js_framesEdge, js_framesSharp ] =
    runBenchmark("JavaScript (main.js)", f1_JS, f2_JS, width, height, frames, SAMPLES, ITERATIONS_JS);
  const [ wasmTotal_ref, wasmAvg_ref, wasm_ref_framesEdge, wasm_ref_framesSharp ] =
    runBenchmark("WebAssembly (main_ref.jazz)", f1_WASM_ref, f2_WASM_ref, width, height, frames, SAMPLES, ITERATIONS_WASM);
  const [ wasmTotal_vec, wasmAvg_vec, wasm_vec_framesEdge, wasm_vec_framesSharp ] =
    runBenchmark("WebAssembly (main_vec.jazz)", f1_WASM_vec, f2_WASM_vec, width, height, frames, SAMPLES, ITERATIONS_WASM);
  const [ wasmTotal_opt, wasmAvg_opt, wasm_opt_framesEdge, wasm_opt_framesSharp ] =
    runBenchmark("WebAssembly (main_opt.jazz)", f1_WASM_opt, f2_WASM_opt, width, height, frames, SAMPLES, ITERATIONS_WASM);

  for (let j = 0; j < Math.min(ITERATIONS_JS, js_framesEdge.length); j++) {
    const js_edge = js_framesEdge[j];
    const js_sharp = js_framesSharp[j];

    const wasm_ref_edge = wasm_ref_framesEdge[j];
    const wasm_ref_sharp = wasm_ref_framesSharp[j];

    const wasm_vec_edge = wasm_vec_framesEdge[j];
    const wasm_vec_sharp = wasm_vec_framesSharp[j];

    const wasm_opt_edge = wasm_opt_framesEdge[j];
    const wasm_opt_sharp = wasm_opt_framesSharp[j];

    for (let i = 0; i < js_edge.length; i++) {
      if (js_edge[i] != wasm_ref_edge[i]) {
        console.error("Error:", js_edge[i], "!=", wasm_ref_edge[i], "when comparing js_framesEdge and wasm_ref_framesEdge");
      }
      if (js_sharp[i] != wasm_ref_sharp[i]) {
        console.error("Error:", js_sharp[i], "!=", wasm_ref_sharp[i], "when comparing js_framesSharp and wasm_ref_framesSharp");
      }

      if (js_edge[i] != wasm_vec_edge[i]) {
        console.error("Error:", js_edge[i], "!=", wasm_vec_edge[i], "when comparing js_framesEdge and wasm_vec_framesEdge");
      }
      if (js_sharp[i] != wasm_vec_sharp[i]) {
        console.error("Error:", js_sharp[i], "!=", wasm_vec_sharp[i], "when comparing js_framesSharp and wasm_vec_framesSharp");
      }

      if (js_edge[i] != wasm_opt_edge[i]) {
        console.error("Error:", js_edge[i], "!=", wasm_opt_edge[i], "when comparing js_framesEdge and wasm_opt_framesEdge");
      }
      if (js_sharp[i] != wasm_opt_sharp[i]) {
        console.error("Error:", js_sharp[i], "!=", wasm_opt_sharp[i], "when comparing js_framesSharp and wasm_opt_framesSharp");
      }
    }
  }

  for (let j = Math.min(ITERATIONS_JS, js_framesEdge.length); j < Math.min(ITERATIONS_WASM, wasm_ref_framesEdge.length); j++) {
    const wasm_ref_edge = wasm_ref_framesEdge[j];
    const wasm_ref_sharp = wasm_ref_framesSharp[j];

    const wasm_vec_edge = wasm_vec_framesEdge[j];
    const wasm_vec_sharp = wasm_vec_framesSharp[j];

    const wasm_opt_edge = wasm_opt_framesEdge[j];
    const wasm_opt_sharp = wasm_opt_framesSharp[j];

    for (let i = 0; i < wasm_ref_edge.length; i++) {

      if (wasm_ref_edge[i] != wasm_vec_edge[i]) {
        console.error("Error:", wasm_ref_edge[i], "!=", wasm_vec_edge[i], "when comparing wasm_ref_framesEdge and wasm_vec_framesEdge");
      }
      if (wasm_ref_sharp[i] != wasm_vec_sharp[i]) {
        console.error("Error:", wasm_ref_sharp[i], "!=", wasm_vec_sharp[i], "when comparing wasm_ref_framesSharp and wasm_vec_framesSharp");
      }

      if (wasm_ref_edge[i] != wasm_opt_edge[i]) {
        console.error("Error:", wasm_ref_edge[i], "!=", wasm_opt_edge[i], "when comparing wasm_ref_framesEdge and wasm_opt_framesEdge");
      }
      if (wasm_ref_sharp[i] != wasm_opt_sharp[i]) {
        console.error("Error:", wasm_ref_sharp[i], "!=", wasm_opt_sharp[i], "when comparing wasm_ref_framesSharp and wasm_opt_framesSharp");
      }
    }
  }

  console.log(`\nRatio JS / WASM_ref : ${(jsAvg / wasmAvg_ref).toFixed(2)}`);
  console.log(`Ratio JS / WASM_vec : ${(jsAvg / wasmAvg_vec).toFixed(2)}`);
  console.log(`Ratio JS / WASM_opt : ${(jsAvg / wasmAvg_opt).toFixed(2)}\n`);
  console.log(`\nRatio WASM_ref / WASM_vec : ${(wasmAvg_ref / wasmAvg_vec).toFixed(2)}`);
  console.log(`Ratio WASM_ref / WASM_opt : ${(wasmAvg_ref / wasmAvg_opt).toFixed(2)}`);
  console.log(`Ratio WASM_vec / WASM_opt : ${(wasmAvg_vec / wasmAvg_opt).toFixed(2)}`);

}


// Main
main();
