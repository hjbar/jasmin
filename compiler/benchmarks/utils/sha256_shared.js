// Import libraries
const { parseArgs, runCoreBenchmark, reportStats } = require('../utils/bench_runner');
const { Buffer } = require('buffer');


// Parse the command line
function parseShaArgs() {

  if (process.argv.length < 6) {
    console.log("Usage: node %s <nb_repeat> <nb_iterations> <input_string> <verbose>", process.argv[1]);
    process.exit(1);
  }

  const { NB_REPEAT, NB_ITER, VERBOSE } = parseArgs();

  return {
    NB_REPEAT: NB_REPEAT,
    NB_ITER: NB_ITER,
    INPUT_STRING: process.argv[4],
    VERBOSE: VERBOSE,
  };

}


// Init args
function initShaArgs(memory) {

  const { NB_REPEAT, NB_ITER, INPUT_STRING, VERBOSE } = parseShaArgs();

  const hash = 50000;
  const input = hash + 32;
  const input_buf = Buffer.from(INPUT_STRING);
  const input_length = input_buf.length;

  const memView = new Uint8Array(memory.buffer);
  memView.set(input_buf, input);

  return {
    NB_REPEAT,
    NB_ITER,
    VERBOSE,
    INPUT_STRING,
    hash,
    input,
    input_length,
    memView,
  };

}


// Benchmark
function benchSha(NB_REPEAT, NB_ITER, hash, input, input_length, fn) {

  return runCoreBenchmark(
    NB_REPEAT,
    NB_ITER,
    () => fn(hash, input, input_length),
    () => fn(hash, input, input_length),
  );

}


// Benchmark with BigInt
function benchShaBigInt(NB_REPEAT, NB_ITER, hash, input, input_length, fn) {

  const hash_arg = BigInt(hash);
  const input_arg = BigInt(input);
  const input_lenth_arg = BigInt(input_length);

  return benchSha(NB_REPEAT, NB_ITER, hash_arg, input_arg, input_lenth_arg, fn);

}


// Compute results
function reportShaStats(results, NB_REPEAT, NB_ITER, INPUT_STRING, VERBOSE, hash, input_length, memView) {

  reportStats(results, NB_REPEAT, NB_ITER);

  if (VERBOSE) {
    const result_hash = memView.slice(hash, hash + 32);
    const hex_hash = Buffer.from(result_hash).toString('hex');
    console.log(`Input         : "${INPUT_STRING}" (${input_length} bytes)`);
    console.log(`Hash          : ${hex_hash}`);
  }

}


// Main aux
async function mainSha(memory, fn, withBigInt = false) {

  const { NB_REPEAT, NB_ITER, VERBOSE, INPUT_STRING, hash, input, input_length, memView } = initShaArgs(memory);

  let results;
  if (withBigInt) {
    results = benchShaBigInt(NB_REPEAT, NB_ITER, hash, input, input_length, fn);
  } else {
    results = benchSha(NB_REPEAT, NB_ITER, hash, input, input_length, fn);
  }

  reportShaStats(results, NB_REPEAT, NB_ITER, INPUT_STRING, VERBOSE, hash, input_length, memView);

}


// Exports
module.exports = {
  mainSha,
};
