// Import libraries
const { parseArgs, runCoreBenchmark, reportStats } = require('../utils/bench_runner');
const { Buffer } = require('buffer');


// Parse the command line
function parseChachaArgs() {

  if (process.argv.length < 8) {
    console.log("Usage: node %s <nb_repeat> <nb_iterations> <input_length> <input_nonce> <input_key> <verbose>", process.argv[1]);
    process.exit(1);
  }

  const { NB_REPEAT, NB_ITER, VERBOSE } = parseArgs();

  return {
    NB_REPEAT: NB_REPEAT,
    NB_ITER: NB_ITER,
    STREAM_LENGTH: parseInt(process.argv[4], 10),
    NONCE_HEX: process.argv[5],
    KEY_HEX: process.argv[6],
    VERBOSE: VERBOSE,
  };

}


// Init args
function initChachaArgs(memory) {

  const { NB_REPEAT, NB_ITER, STREAM_LENGTH, NONCE_HEX, KEY_HEX, VERBOSE } = parseChachaArgs();

  const nonceBuf = Buffer.alloc(12, 0).fill(NONCE_HEX, 'hex');
  const keyBuf = Buffer.alloc(32, 0).fill(KEY_HEX, 'hex');

  const streamPtr = 0;
  const noncePtr = streamPtr + (STREAM_LENGTH > 0 ? STREAM_LENGTH : 1);
  const keyPtr = noncePtr + 12;

  const memView = new Uint8Array(memory.buffer);
  memView.set(keyBuf, keyPtr);
  memView.set(nonceBuf, noncePtr);

  return {
    NB_REPEAT,
    NB_ITER,
    STREAM_LENGTH,
    VERBOSE,
    streamPtr,
    noncePtr,
    keyPtr,
    memView,
  };

}


// Benchmark
function benchChacha(NB_REPEAT, NB_ITER, streamPtr, STREAM_LENGTH, noncePtr, keyPtr, fn) {

  return runCoreBenchmark(
    NB_REPEAT,
    NB_ITER,
    () => fn(streamPtr, STREAM_LENGTH, noncePtr, keyPtr),
    () => fn(streamPtr, STREAM_LENGTH, noncePtr, keyPtr),
  );

}


// Benchmark with BigInt
function benchChachaBigInt(NB_REPEAT, NB_ITER, streamPtr, STREAM_LENGTH, noncePtr, keyPtr, fn) {

  const pStream = BigInt(streamPtr);
  const lenStream = BigInt(STREAM_LENGTH);
  const pNonce = BigInt(noncePtr);
  const pKey = BigInt(keyPtr);

  return benchChacha(NB_REPEAT, NB_ITER, pStream, lenStream, pNonce, pKey, fn);

}


// Compute results
function reportChachaStats(results, NB_REPEAT, NB_ITER, STREAM_LENGTH, VERBOSE, streamPtr, memView) {

  reportStats(results, NB_REPEAT, NB_ITER);

  if (VERBOSE) {
    const resultStream = memView.slice(streamPtr, streamPtr + STREAM_LENGTH);
    const hexResult = Buffer.from(resultStream).toString('hex');
    console.log(`Result        : ${hexResult}`);
  }

}


// Main aux
async function mainChacha(memory, fn, withBigInt = false) {

  const { NB_REPEAT, NB_ITER, STREAM_LENGTH, VERBOSE, streamPtr, noncePtr, keyPtr, memView } = initChachaArgs(memory);

  let results;
  if (withBigInt) {
    results = benchChachaBigInt(NB_REPEAT, NB_ITER, streamPtr, STREAM_LENGTH, noncePtr, keyPtr, fn);
  } else {
    results = benchChacha(NB_REPEAT, NB_ITER, streamPtr, STREAM_LENGTH, noncePtr, keyPtr, fn);
  }

  reportChachaStats(results, NB_REPEAT, NB_ITER, STREAM_LENGTH, VERBOSE, streamPtr, memView);

}


// Exports
module.exports = {
  mainChacha,
};
