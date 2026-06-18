// SpiderMonkey
globalThis.__currentAlgoDir = 'chacha20-opt';


// Import libraries
const { initWasm } = require('../utils/bench_runner');
const { mainChacha } = require('../utils/chacha20_shared');


// Main function
async function main() {

  const { exports, memory } = await initWasm(__dirname, 'chacha20-opt_wasm.wasm');
  const fn = exports.jade_stream_chacha_chacha20_amd64_ref;
  mainChacha(memory, fn, withBigInt = false);

}


// Main
main().catch(console.error);
