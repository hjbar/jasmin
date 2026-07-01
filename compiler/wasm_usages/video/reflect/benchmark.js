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
  WebAssembly: WebAssembly
};


// Virtual Machine to make the connection with the web part of the code
const context = vm.createContext(browserMock);


// Read the main file
try {
  const mainJsCode = fs.readFileSync('./main.js', 'utf8');
  vm.runInContext(mainJsCode, context);
} catch (err) {
  console.error("Impossible to read main.js :", err);
  process.exit(1);
}


// Get the wanted functions of main.js
const { inner_computeFrame_JS, inner_computeFrame_WASM } = context;


// Init the Wasm module with the Node stuff
async function initWasm(path, width, height, frameSize) {

  const wasmBuffer = fs.readFileSync(path);
  const memory = new WebAssembly.Memory({ initial: 1024 });
  const importObject = { env: { memory } };

  const { instance } = await WebAssembly.instantiate(wasmBuffer, importObject);
  const fnWasm = instance.exports.inner_computeFrame;

  const buffer = memory.buffer;
  const ptrData = 50000;
  const wasmData = new Uint8ClampedArray(buffer, ptrData, frameSize);

  return function computeFrame_Wasm(data, width, height, step) {
    inner_computeFrame_WASM(data, width, height, step, fnWasm, ptrData, wasmData);
  };

}


// Extract data from the video
function extractFramesFromVideo(videoPath, targetHeight) {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(videoPath, (err, metadata) => {

      if (err) return reject(err);

      const videoStream = metadata.streams.find(s => s.codec_type === 'video');
      if (!videoStream) return reject(new Error("No video found."));

      const width = videoStream.width;
      const originalHeight = videoStream.height;

      const height = Math.min(targetHeight, Math.floor(originalHeight / 3));
      const frameSize = width * height * 4;

      const frames = [];
      let currentBuffer = Buffer.alloc(0);

      console.log(`[FFmpeg] Original video: ${width}x${originalHeight} -> New video: ${width}x${height}`);

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
function runBenchmark(label, computeStrategy, width, height, frames, samples, iterations) {

  // Init args
  const step = Math.round(256 / height);

  // Warmup
  const warmupData = new Uint8ClampedArray(frames[0]);
  for (let k = 0; k < (iterations * 0.1); k++) {
    computeStrategy(warmupData, width, height, step);
  }

  // Benchmark
  const framesCopy = frames.map(f => new Uint8ClampedArray(f))
  let totalTime = 0;

  for (let j = 0; j < samples; j++) {
    for (let i = 0; i < iterations; i++) {

    const frameIndex = i % framesCopy.length;
    const frame_i = framesCopy[frameIndex];

    const start = performance.now();
    computeStrategy(frame_i, width, height, step);
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

  return [ totalTime, avgTime, framesCopy ];
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
  const ITERATIONS = parseInt(process.argv[4], 10);

  // Init params
  const TARGET_HEIGHT = 256;

  const { width, height, frameSize, frames } = await extractFramesFromVideo(videoPath, TARGET_HEIGHT);
  if (frames.length === 0) {
    console.error("Error: no frame computed from the video.");
    process.exit(1);
  }

  const inner_computeFrame_WASM_ref = await initWasm('./main_ref.wasm', width, height, frameSize);
  const inner_computeFrame_WASM_vec = await initWasm('./main_vec.wasm', width, height, frameSize);
  const inner_computeFrame_WASM_opt = await initWasm('./main_opt.wasm', width, height, frameSize);

  // Start the benchmark
  console.log(`\n\nBenchmark (${width}x${height} video dimensions, ${SAMPLES} samples, ${ITERATIONS} iterations)...\n`);

  const [ jsTotal, jsAvg, js_frames ] =
    runBenchmark("JavaScript (main.js)", inner_computeFrame_JS, width, height, frames, SAMPLES, ITERATIONS);
  const [ wasmTotal_ref, wasmAvg_ref, wasm_ref_frames ] =
    runBenchmark("WebAssembly (main_ref.jazz)", inner_computeFrame_WASM_ref, width, height, frames, SAMPLES, ITERATIONS);
  const [ wasmTotal_vec, wasmAvg_vec, wasm_vec_frames ] =
    runBenchmark("WebAssembly (main_vec.jazz)", inner_computeFrame_WASM_vec, width, height, frames, SAMPLES, ITERATIONS);
  const [ wasmTotal_opt, wasmAvg_opt, wasm_opt_frames ] =
    runBenchmark("WebAssembly (main_opt.jazz)", inner_computeFrame_WASM_opt, width, height, frames, SAMPLES, ITERATIONS);

  for (let j = 0; j < Math.min(ITERATIONS, js_frames.length); j++) {
    js_data = js_frames[j];
    wasm_ref_data = wasm_ref_frames[j];
    wasm_vec_data = wasm_vec_frames[j];
    wasm_opt_data = wasm_opt_frames[j];

    for (let i = 0; i < js_data.length; i++) {
      if (js_data[i] != wasm_ref_data[i]) {
        console.error("Error:", js_data[i], "!=", wasm_ref_data[i], "when comparing JS and Wasm_ref");
      }
      if (js_data[i] != wasm_vec_data[i]) {
        console.error("Error:", js_data[i], "!=", wasm_vec_data[i], "when comparing JS and Wasm_vec");
      }
      if (js_data[i] != wasm_opt_data[i]) {
        console.error("Error:", js_data[i], "!=", wasm_opt_data[i], "when comparing JS and Wasm_opt");
      }
    }
  }

  console.log(`\nRatio JS / WASM_ref : ${(jsTotal / wasmTotal_ref).toFixed(2)}`);
  console.log(`Ratio JS / WASM_vec : ${(jsTotal / wasmTotal_vec).toFixed(2)}`);
  console.log(`Ratio JS / WASM_opt : ${(jsTotal / wasmTotal_opt).toFixed(2)}\n`);
  console.log(`\nRatio WASM_ref / WASM_vec : ${(wasmTotal_ref / wasmTotal_vec).toFixed(2)}`);
  console.log(`Ratio WASM_ref / WASM_opt : ${(wasmTotal_ref / wasmTotal_opt).toFixed(2)}`);
  console.log(`Ratio WASM_vec / WASM_opt : ${(wasmTotal_vec / wasmTotal_opt).toFixed(2)}`);

}


// Main
main();
