// Import libraries
const fs = require('fs');
const path = require('path');
const { performance } = require('perf_hooks');

  // Parse the command line
if (process.argv.length < 5) {
  console.log("Usage: node %s <nb_repeat> <nb_iterations> <verbose>", process.argv[1]);
  process.exit(1);
}

const NB_REPEAT = parseInt(process.argv[2], 10);
const NB_ITER = parseInt(process.argv[3], 10);
const WARMUP_ITER = Math.floor(NB_ITER * 0.1);
const VERBOSE = parseInt(process.argv[4], 10);

// Run the wasm function
async function runWasm() {
  // Init args
  const wasmPath = path.join(__dirname, 'prog/gimli_wasm.wasm');
  const wasmBuffer = fs.readFileSync(wasmPath);

  const memory = new WebAssembly.Memory({ initial: 1024 });
  const importObject = { env: { memory: memory, } };

  const { instance } = await WebAssembly.instantiate(wasmBuffer, importObject);
  const exports = instance.exports;

  const state_ptr = 50000;
  const state = new Uint32Array(memory.buffer, state_ptr, 12);
  for (let i = 0; i < 12; i++) {
    state[i] = (i * i * i + i * 0x9e3779b9) >>> 0;
  }
  const input_state = Array.from(state).map(val => val.toString(16).padStart(8, '0')).join(' ');

  const results = [];

  // Warmup
  for (let i = 0; i < WARMUP_ITER; i++) {
    exports.gimli(state_ptr);
  }

  // Benchmark
  for (let i = 0; i < NB_REPEAT; i++) {
    const start = process.hrtime.bigint();

    for (let j = 0; j < NB_ITER; j++) {
      exports.gimli(state_ptr);
    }

    const end = process.hrtime.bigint();
    results.push(Number(end - start) / 1e9);
  }

  // Compute the result
  const sum = results.reduce((a, b) => a + b, 0);
  const mean = sum / NB_REPEAT;

  const variance = results.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / NB_REPEAT;
  const stdDev = Math.sqrt(variance);

  const result_state = Array.from(state).map(val => val.toString(16).padStart(8, '0')).join(' ');

  {
    console.log(`Samples       : ${NB_REPEAT}`                                                          );
    console.log(`Iterations    : ${NB_ITER}`                                                            );
    console.log(`Mean time     : ${mean.toFixed(6)}s`                                                   );
    console.log(`Std Deviation : ${stdDev.toFixed(6)}s (${((stdDev / mean) * 100).toFixed(6)}% of mean)`);
    console.log(`Avg per call  : ${((mean * 1e9) / NB_ITER).toFixed(6)}ns`                              );
  }
  if (VERBOSE) {
    console.log(`Input         : ${input_state}`                                                        );
    console.log(`Result        : ${result_state}`                                                       );
  }

  return 0;
}

// Main
runWasm().catch(console.error);
