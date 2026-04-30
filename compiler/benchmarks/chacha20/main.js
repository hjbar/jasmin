// Import libraries
const fs = require('fs');
const path = require('path');

  // Parse the command line
if (process.argv.length < 8) {
  console.log("Usage: node %s <nb_repeat> <nb_iterations> <input_length> <input_nonce> <input_key> <verbose>", process.argv[1]);
  process.exit(1);
}

const NB_REPEAT = parseInt(process.argv[2], 10);
const NB_ITER = parseInt(process.argv[3], 10);
const WARMUP_ITER = Math.floor(NB_ITER * 0.1);
const STREAM_LENGTH = parseInt(process.argv[4], 10);
const NONCE_HEX = process.argv[5];
const KEY_HEX = process.argv[6];
const VERBOSE = parseInt(process.argv[7], 10);

// Run the wasm function
async function runWasm() {
  // Init args
  const wasmPath = path.join(__dirname, 'prog/chacha20_wasm.wasm');
  const wasmBuffer = fs.readFileSync(wasmPath);

  const memory = new WebAssembly.Memory({ initial: 1024 });
  const importObject = { env: { memory: memory, } };

  const { instance } = await WebAssembly.instantiate(wasmBuffer, importObject);
  const exports = instance.exports;

  const nonceBuf = Buffer.alloc(12, 0);
  nonceBuf.write(NONCE_HEX, 0, 'hex');
  const keyBuf = Buffer.alloc(32, 0);
  keyBuf.write(KEY_HEX, 0, 'hex')

  const streamPtr = 0;
  const noncePtr = streamPtr + (STREAM_LENGTH > 0 ? STREAM_LENGTH : 1);
  const keyPtr = noncePtr + 12;

  const memView = new Uint8Array(memory.buffer);
  memView.set(keyBuf, keyPtr);
  memView.set(nonceBuf, noncePtr);

  const pStream = BigInt(streamPtr);
  const lenStream = BigInt(STREAM_LENGTH);
  const pKey = BigInt(keyPtr);
  const pNonce = BigInt(noncePtr);

  const results = [];

  // Warmup
  for (let i = 0; i < WARMUP_ITER; i++) {
    exports.jade_stream_chacha_chacha20_amd64_ref(pStream, lenStream, pNonce, pKey);
  }

  // Benchmark
  for (let i = 0; i < NB_REPEAT; i++) {
    const start = process.hrtime.bigint();

    for (let j = 0; j < NB_ITER; j++) {
      exports.jade_stream_chacha_chacha20_amd64_ref(pStream, lenStream, pNonce, pKey);
    }

    const end = process.hrtime.bigint();
    results.push(Number(end - start) / 1e9);
  }

  // Compute the result
  const sum = results.reduce((a, b) => a + b, 0);
  const mean = sum / NB_REPEAT;

  const variance = results.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / NB_REPEAT;
  const stdDev = Math.sqrt(variance);

  const resultStream = memView.slice(streamPtr, streamPtr + STREAM_LENGTH);
  const hexResult = Buffer.from(resultStream).toString('hex');

  {
    console.log(`Samples       : ${NB_REPEAT}`                                                          );
    console.log(`Iterations    : ${NB_ITER}`                                                            );
    console.log(`Mean time     : ${mean.toFixed(6)}s`                                                   );
    console.log(`Std Deviation : ${stdDev.toFixed(6)}s (${((stdDev / mean) * 100).toFixed(6)}% of mean)`);
    console.log(`Avg per call  : ${((mean * 1e9) / NB_ITER).toFixed(6)}ns`                              );
  }
  if (VERBOSE) {
    console.log(`Result        : ${hexResult}`                                                          );
  }

  return 0;
}

// Main
runWasm().catch(console.error);
