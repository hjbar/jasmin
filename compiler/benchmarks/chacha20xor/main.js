// Import libraries
const { initWasm } = require('../utils/bench_runner');
const { mainChachaXor } = require('../utils/chacha20xor_shared');


// Main function
async function main() {

  const { exports, memory } = await initWasm('chacha20xor/prog/chacha20xor_wasm.wasm');
  const fn = exports.jade_stream_chacha_chacha20_amd64_ref_xor;
  mainChachaXor(memory, fn, withBigInt = true);

}


// Main
main().catch(console.error);
