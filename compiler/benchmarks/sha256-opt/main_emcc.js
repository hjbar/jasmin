// SpiderMonkey
globalThis.__currentAlgoDir = 'sha256-opt';


// Import libraries
const { initWasmEmcc } = require('../utils/bench_runner');
const { mainSha } = require('../utils/sha256_shared');


// Main function
async function main() {

  const { exports, memory } = await initWasmEmcc(__dirname, 'sha256-opt_wasm.wasm');
  const fn = exports.jade_hash_sha256_amd64_ref;
  mainSha(memory, fn, withBigInt = false);

}


// Main
main().catch(console.error);
