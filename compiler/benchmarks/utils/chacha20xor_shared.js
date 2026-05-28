// Import libraries
const { parseArgs, runCoreBenchmark, reportStats } = require('../utils/bench_runner');
const { Buffer } = require('buffer');


// Parse the command line
function parseChachaXorArgs() {

  if (process.argv.length < 8) {
    console.log("Usage: node %s <nb_repeat> <nb_iterations> <input> <input_nonce> <input_key> <verbose>", process.argv[1]);
    process.exit(1);
  }

  const { NB_REPEAT, NB_ITER, VERBOSE } = parseArgs();

  return {
    NB_REPEAT: NB_REPEAT,
    NB_ITER: NB_ITER,
    INPUT_RAW: process.argv[4],
    INPUT_LENGTH: process.argv[4].length,
    NONCE_HEX: process.argv[5],
    KEY_HEX: process.argv[6],
    VERBOSE: VERBOSE,
  };

}


// Init args
function initChachaXorArgs(memory) {

  const { NB_REPEAT, NB_ITER, INPUT_RAW, INPUT_LENGTH, NONCE_HEX, KEY_HEX, VERBOSE } = parseChachaXorArgs();

  const inputBuf = Buffer.from(INPUT_RAW, 'utf8');
  const nonceBuf = Buffer.alloc(12, 0).fill(NONCE_HEX, 'hex');
  const keyBuf = Buffer.alloc(32, 0).fill(KEY_HEX, 'hex');

  const outPtr = 50000;
  const inPtr = outPtr + (INPUT_LENGTH > 0 ? INPUT_LENGTH : 1);
  const noncePtr = inPtr + (INPUT_LENGTH > 0 ? INPUT_LENGTH : 1);
  const keyPtr = noncePtr + 12;

  const memView = new Uint8Array(memory.buffer);
  memView.set(inputBuf, inPtr);
  memView.set(nonceBuf, noncePtr);
  memView.set(keyBuf, keyPtr);

  return {
    NB_REPEAT,
    NB_ITER,
    INPUT_LENGTH,
    VERBOSE,
    outPtr,
    inPtr,
    noncePtr,
    keyPtr,
    memView,
  };

}


// Benchmark
function benchChachaXor(NB_REPEAT, NB_ITER, INPUT_LENGTH, outPtr, inPtr, noncePtr, keyPtr, fn) {

  return runCoreBenchmark(
    NB_REPEAT,
    NB_ITER,
    () => fn(outPtr, inPtr, INPUT_LENGTH, noncePtr, keyPtr),
    () => fn(outPtr, inPtr, INPUT_LENGTH, noncePtr, keyPtr),
  );

}


// Benchmark with BigInt
function benchChachaXorBigInt(NB_REPEAT, NB_ITER, INPUT_LENGTH, outPtr, inPtr, noncePtr, keyPtr, fn) {

  const len = BigInt(INPUT_LENGTH);
  const pOut = BigInt(outPtr);
  const pIn = BigInt(inPtr);
  const pNonce = BigInt(noncePtr);
  const pKey = BigInt(keyPtr);

  return benchChachaXor(NB_REPEAT, NB_ITER, len, pOut, pIn, pNonce, pKey, fn);

}


// Compute results
function reportChachaXorStats(results, NB_REPEAT, NB_ITER, INPUT_LENGTH, VERBOSE, outPtr, memView) {

  reportStats(results, NB_REPEAT, NB_ITER);

  if (VERBOSE) {
    const resultStream = memView.slice(outPtr, outPtr + INPUT_LENGTH);
    const hexResult = Buffer.from(resultStream).toString('hex');
    console.log(`Result        : ${hexResult}`);
  }

}


// Main aux
async function mainChachaXor(memory, fn, withBigInt = false) {

  const { NB_REPEAT, NB_ITER, INPUT_LENGTH, VERBOSE, outPtr, inPtr, noncePtr, keyPtr, memView } = initChachaXorArgs(memory);

  let results;
  if (withBigInt) {
    results = benchChachaXorBigInt(NB_REPEAT, NB_ITER, INPUT_LENGTH, outPtr, inPtr, noncePtr, keyPtr, fn);
  } else {
    results = benchChachaXor(NB_REPEAT, NB_ITER, INPUT_LENGTH, outPtr, inPtr, noncePtr, keyPtr, fn);
  }

  reportChachaXorStats(results, NB_REPEAT, NB_ITER, INPUT_LENGTH, VERBOSE, outPtr, memView);

}


// Exports
module.exports = {
  mainChachaXor,
};
