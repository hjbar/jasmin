// Import libraries
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Parse program inputs
function parseInputs() {
  const [,, rawPath, rawSize, rawNumber] = process.argv;

  if (!rawPath || !rawSize || !rawNumber) {
    console.error("Usage: node main.js <path> <size> <number>");
    process.exit(1);
  }

  const absolutePath = path.resolve(rawPath);
  const size = parseInt(rawSize, 10);

  let number;
  if (size === 32) {
    number = parseInt(rawNumber, 10);

    if (isNaN(number)) {
      console.error(`Erreur : "${rawNumber}" n'est pas un nombre valide.`);
      process.exit(1);
    }

    number = number | 0;
  }
  else if (size === 64) {
    try {
      number = BigInt(rawNumber);
    }
    catch (err) {
      console.error(err);
      process.exit(1);
    }
  }
  else {
    console.error("Error: Size should be equal to 32 or 64, not to", size);
    process.exit(1);
  }

  return { absolutePath, size, number };
}

// RandomBytes Jasmin Syscall
const jasmin_syscall_randombytes = (wasmMemory) => {
  return (ptr, len) => {
    const offset = Number(ptr);
    const size = Number(len);

    if (size > 0) {
      const buffer = new Uint8Array(wasmMemory.buffer, offset, size);

      const cryptoAPI = globalThis.crypto || require('node:crypto').webcrypto;

      const MAX_CHUNK = 65536;
      for (let i = 0; i < size; i += MAX_CHUNK) {
        const chunk = buffer.subarray(i, Math.min(i + MAX_CHUNK, size));
        cryptoAPI.getRandomValues(chunk);
      }
    }

    return ptr;
  };
};

// Wrap the Wasm program
async function runWasm(path, size, number) {
  try {
    const wasmBuffer = fs.readFileSync(path);

    const memory = new WebAssembly.Memory({ initial: 1024, maximum: 32768 });
    const importObject = {
      env: {
        memory: memory,
        __jasmin_syscall_randombytes__: jasmin_syscall_randombytes(memory)
      }
    };

    const { instance } = await WebAssembly.instantiate(wasmBuffer, importObject);
    const result = instance.exports.main_test(number);

    if (size === 64) {
      console.log(result.toString());
    }
    else {
      console.log(result);
    }
  }
  catch (err) {
    console.error(err);
  }
}

// Main
const args = parseInputs();
runWasm(args.absolutePath, args.size, args.number);
