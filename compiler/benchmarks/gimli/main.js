// SpiderMonkey
globalThis.__currentAlgoDir = 'gimli';


// Import libraries
const { parseArgs, initWasm, runCoreBenchmark, reportStats } = require('../utils/bench_runner');


// Parse the command line
if (process.argv.length < 5) {
  console.log("Usage: node %s <nb_repeat> <nb_iterations> <verbose>", process.argv[1]);
  process.exit(1);
}

const { NB_REPEAT, NB_ITER, VERBOSE } = parseArgs();


// Main function
async function main() {

  // Init args
  const { exports, memory } = await initWasm(__dirname, 'gimli_wasm.wasm');
  const fn = exports.gimli;

  const state_ptr = 50000;
  const state = new Uint32Array(memory.buffer, state_ptr, 12);
  for (let i = 0; i < 12; i++) {
    state[i] = (i * i * i + i * 0x9e3779b9) >>> 0;
  }
  const input_state = Array.from(state).map(val => val.toString(16).padStart(8, '0')).join(' ');


  // Benchmark
  const results = runCoreBenchmark(
    NB_REPEAT,
    NB_ITER,
    () => fn(state_ptr),
    () => fn(state_ptr),
  );


  // Compute results
  reportStats(results, NB_REPEAT, NB_ITER);

  if (VERBOSE) {
    const result_state = Array.from(state).map(val => val.toString(16).padStart(8, '0')).join(' ');
    console.log(`Input         : ${input_state}`);
    console.log(`Result        : ${result_state}`);
  }

}


// Main
main().catch(console.error);
