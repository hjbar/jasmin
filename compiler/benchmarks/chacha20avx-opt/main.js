// Import libraries
const { initWasm } = require('../utils/bench_runner');
const { mainChacha } = require('../utils/chacha20_shared');


// Main function
async function main() {

  const { exports, memory } = await initWasm('chacha20avx-opt/prog/chacha20avx-opt_wasm.wasm');
  const fn = exports.jade_stream_chacha_chacha20_amd64_avx;
  mainChacha(memory, fn, withBigInt = false);

}


// Main
main().catch(console.error);
