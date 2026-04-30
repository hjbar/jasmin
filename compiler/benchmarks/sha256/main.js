// Import libraries
const fs = require('fs');
const path = require('path');
const { performance } = require('perf_hooks');

  // Parse the command line
if (process.argv.length < 6) {
  console.log("Usage: node %s <nb_repeat> <nb_iterations> <input_string> <verbose>", process.argv[1]);
  process.exit(1);
}

const NB_REPEAT = parseInt(process.argv[2], 10);
const NB_ITER = parseInt(process.argv[3], 10);
const WARMUP_ITER = Math.floor(NB_ITER * 0.1);
const INPUT_STRING = process.argv[4];
const VERBOSE = parseInt(process.argv[5], 10);

// Run the wasm function
async function runWasm() {
  // Init args
  const wasmPath = path.join(__dirname, 'prog/sha256_wasm.wasm');
  const wasmBuffer = fs.readFileSync(wasmPath);

  const memory = new WebAssembly.Memory({ initial: 1024 });
  const importObject = { env: { memory: memory, } };

  const { instance } = await WebAssembly.instantiate(wasmBuffer, importObject);
  const exports = instance.exports;

  const hash = 50000;
  const input_buf = Buffer.from(INPUT_STRING);
  const input_length = input_buf.length;
  const input = hash + 32;

  const memView = new Uint8Array(memory.buffer);
  memView.set(input_buf, input);

  const hash_arg = BigInt(hash);
  const input_lenth_arg = BigInt(input_length);
  const input_arg = BigInt(input);

  const results = [];

  // Warmup
  for (let i = 0; i < WARMUP_ITER; i++) {
    exports.jade_hash_sha256_amd64_ref(hash_arg, input_arg, input_lenth_arg);
  }

  // Benchmark
  for (let i = 0; i < NB_REPEAT; i++) {
    const start = process.hrtime.bigint();

    for (let j = 0; j < NB_ITER; j++) {
      exports.jade_hash_sha256_amd64_ref(hash_arg, input_arg, input_lenth_arg);
    }

    const end = process.hrtime.bigint();
    results.push(Number(end - start) / 1e9);
  }

  // Compute the result
  const sum = results.reduce((a, b) => a + b, 0);
  const mean = sum / NB_REPEAT;

  const variance = results.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / NB_REPEAT;
  const stdDev = Math.sqrt(variance);

  const result_hash = memView.slice(hash, hash + 32);
  const hex_hash = Buffer.from(result_hash).toString('hex');

  {
    console.log(`Samples       : ${NB_REPEAT}`                                                          );
    console.log(`Iterations    : ${NB_ITER}`                                                            );
    console.log(`Mean time     : ${mean.toFixed(6)}s`                                                   );
    console.log(`Std Deviation : ${stdDev.toFixed(6)}s (${((stdDev / mean) * 100).toFixed(6)}% of mean)`);
    console.log(`Avg per call  : ${((mean * 1e9) / NB_ITER).toFixed(6)}ns`                              );
  }
  if (VERBOSE) {
    console.log(`Input         : "${INPUT_STRING}" (${input_length} bytes)`                             );
    console.log(`Hash          : ${hex_hash}`                                                           );
  }

  return 0;
}

// Main
runWasm().catch(console.error);
