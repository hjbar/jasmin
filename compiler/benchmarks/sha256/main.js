// Import libraries
const { initWasm } = require('../utils/bench_runner');
const { mainSha } = require('../utils/sha256_shared');


// Main function
async function main() {

  const { exports, memory } = await initWasm('sha256/prog/sha256_wasm.wasm');
  const fn = exports.jade_hash_sha256_amd64_ref;
  mainSha(memory, fn, withBigInt = true);

}


// Main
main().catch(console.error);
