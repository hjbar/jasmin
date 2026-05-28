// Import libraries
const fs = require('fs');
const path = require('path');


// Parse the command line
function parseArgs() {

  if (process.argv.length < 5) {
    console.log("There is no enough args");
    process.exit(1);
  }

  return {
    NB_REPEAT: parseInt(process.argv[2], 10),
    NB_ITER: parseInt(process.argv[3], 10),
    VERBOSE: parseInt(process.argv[process.argv.length - 1], 10),
  };

}


// Init Wasm module
async function initWasm(wasmRelativePath) {

  const wasmPath = path.join(process.cwd(), wasmRelativePath);
  const wasmBuffer = fs.readFileSync(wasmPath);

  const memory = new WebAssembly.Memory({ initial: 1024 });
  const importObject = { env: { memory: memory, } };

  const { instance } = await WebAssembly.instantiate(wasmBuffer, importObject);
  return { exports: instance.exports, memory };

}


// Benchmark function
function runCoreBenchmark(NB_REPEAT, NB_ITER, warmupFn, benchFn) {

  // Init args
  const WARMUP_ITER = Math.floor(NB_ITER * 0.1);
  const results = [];

  // Warmup
  for (let i = 0; i < WARMUP_ITER; i++) {
    warmupFn();
  }

  // Benchmark
  for (let i = 0; i < NB_REPEAT; i++) {
    const start = process.hrtime.bigint();

    for (let j = 0; j < NB_ITER; j++) {
      benchFn();
    }

    const end = process.hrtime.bigint();
    results.push(Number(end - start) / 1e9);
  }

  // Return results
  return results;

}


// Compute results
function reportStats(results, NB_REPEAT, NB_ITER) {

  const sum = results.reduce((a, b) => a + b, 0);
  const mean = sum / NB_REPEAT;

  const variance = results.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / NB_REPEAT;
  const stdDev = Math.sqrt(variance);

  console.log(`Samples       : ${NB_REPEAT}`                                                          );
  console.log(`Iterations    : ${NB_ITER}`                                                            );
  console.log(`Mean time     : ${mean.toFixed(6)}s`                                                   );
  console.log(`Std Deviation : ${stdDev.toFixed(6)}s (${((stdDev / mean) * 100).toFixed(6)}% of mean)`);
  console.log(`Avg per call  : ${((mean * 1e9) / NB_ITER).toFixed(6)}ns`                              );

}


// Exports
module.exports = {
  parseArgs,
  initWasm,
  runCoreBenchmark,
  reportStats,
};
