// Import libraries
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Parse program inputs
function parseInputs() {
  const [,, rawPath, rawSize, rawN, ...rawValues] = process.argv;

  if (!rawPath || !rawSize || !rawN) {
    console.error("Usage: node main.js <path> <size> <N> <val1> ... <valN>");
    process.exit(1);
  }

  const absolutePath = path.resolve(rawPath);
  const size = parseInt(rawSize, 10);
  const N = parseInt(rawN, 10);

  if (rawValues.length !== N) {
    console.error(`Error : Expected ${N} values, got ${rawValues.length}`);
    process.exit(1);
  }

  const args = rawValues.map(val => {

    // Special case for SHA256-OPT
    if (rawPath.includes('sha256-opt')) {
      return val;
    }

    // Special case for SHA256
    if (rawPath.includes('sha256')) {
      return val;
    }

    // Special case for CHACHA20XORAVX-OPT
    if (rawPath.includes('chacha20xoravx-opt')) {
      return val;
    }

    // Special case for CHACHA20XORAVX
    if (rawPath.includes('chacha20xoravx')) {
      return val;
    }

    // Special case for CHACHA20AVX-OPT
    if (rawPath.includes('chacha20avx-opt')) {
      return val;
    }

    // Special case for CHACHA20AVX
    if (rawPath.includes('chacha20avx')) {
      return val;
    }

    // Special case for CHACHA20XOR-OPT
    if (rawPath.includes('chacha20xor-opt')) {
      return val;
    }

    // Special case for CHACHA20XOR
    if (rawPath.includes('chacha20xor')) {
      return val;
    }

    // Special case for CHACHA20-OPT
    if (rawPath.includes('chacha20-opt')) {
      return val;
    }

    // Special case for CHACHA20
    if (rawPath.includes('chacha20')) {
      return val;
    }

    // Special case for GC001
    if (rawPath.includes('gc001')) {
      return val;
    }

    // Common cases
    if (size === 32) {

      const n = parseInt(val, 10);
      if (isNaN(n)) {
        console.error(`Erreor : "${val}" is not a valid 32 bits integer.`);
        process.exit(1);
      }
      return n | 0;

    } else if (size === 64) {

      try {
        return BigInt(val);
      } catch (err) {
        console.error(`Error : "${val}" is not a valid 64 bits integer.`);
        process.exit(1);
      }

    } else {

      console.error("Error: Size should be equal to 32 or 64, not to", size);
      process.exit(1);

    }
  });

  return { absolutePath, size, args };
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
async function runWasm(path, size, args) {
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

    // Special case for SHA256-OPT
    if (path.includes('sha256-opt')) {
      const inputArg = process.argv[5];
      let bufferToHash;

      if (!isNaN(inputArg) && inputArg.trim() !== "") {
        bufferToHash = new Uint8Array(Number(inputArg));
      } else {
        bufferToHash = new TextEncoder().encode(inputArg);
      }

      const len = bufferToHash.length;
      const out_ptr = 50000;
      const in_ptr = out_ptr + len;

      const memView = new Uint8Array(memory.buffer);
      memView.set(bufferToHash, in_ptr);

      instance.exports.main_test(BigInt(out_ptr), BigInt(in_ptr), BigInt(len));

      const outputArray = new Uint8Array(memory.buffer, out_ptr, 32);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for SHA256
    if (path.includes('sha256')) {
      const inputArg = process.argv[5];
      let bufferToHash;

      if (!isNaN(inputArg) && inputArg.trim() !== "") {
        bufferToHash = new Uint8Array(Number(inputArg));
      } else {
        bufferToHash = new TextEncoder().encode(inputArg);
      }

      const len = bufferToHash.length;
      const out_ptr = 50000;
      const in_ptr = out_ptr + len;

      const memView = new Uint8Array(memory.buffer);
      memView.set(bufferToHash, in_ptr);

      instance.exports.main_test(BigInt(out_ptr), BigInt(in_ptr), BigInt(len));

      const outputArray = new Uint8Array(memory.buffer, out_ptr, 32);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for CHACHA20XORAVX-OPT
    if (path.includes('chacha20xoravx-opt')) {
      const len = Number(process.argv[5]);
      const inputHex = process.argv[6];
      const keyHex   = process.argv[7];
      const nonceHex = process.argv[8];

      const outPtr = 50000;
      const inPtr  = outPtr + len;
      const noncePtr = inPtr + len;
      const keyPtr = noncePtr + 12;

      const inputBytes = Buffer.from(inputHex, 'hex');
      const keyBytes   = Buffer.from(keyHex, 'hex');
      const nonceBytes = Buffer.from(nonceHex, 'hex');

      const memView = new Uint8Array(memory.buffer);
      if (len > 0) memView.set(inputBytes, inPtr);
      memView.set(nonceBytes, noncePtr);
      memView.set(keyBytes, keyPtr);

      instance.exports.main_test(BigInt(outPtr), BigInt(inPtr), BigInt(len), BigInt(noncePtr), BigInt(keyPtr));

      const outputArray = new Uint8Array(memory.buffer, outPtr, len);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for CHACHA20XORAVX
    if (path.includes('chacha20xoravx')) {
      const len = Number(process.argv[5]);
      const inputHex = process.argv[6];
      const keyHex   = process.argv[7];
      const nonceHex = process.argv[8];

      const outPtr = 50000;
      const inPtr  = outPtr + len;
      const noncePtr = inPtr + len;
      const keyPtr = noncePtr + 12;

      const inputBytes = Buffer.from(inputHex, 'hex');
      const keyBytes   = Buffer.from(keyHex, 'hex');
      const nonceBytes = Buffer.from(nonceHex, 'hex');

      const memView = new Uint8Array(memory.buffer);
      if (len > 0) memView.set(inputBytes, inPtr);
      memView.set(nonceBytes, noncePtr);
      memView.set(keyBytes, keyPtr);

      instance.exports.main_test(BigInt(outPtr), BigInt(inPtr), BigInt(len), BigInt(noncePtr), BigInt(keyPtr));

      const outputArray = new Uint8Array(memory.buffer, outPtr, len);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for CHACHA20AVX-OPT
    if (path.includes('chacha20avx-opt')) {
      const len = Number(process.argv[5]);
      const keyHex = process.argv[6];
      const nonceHex = process.argv[7];

      const outPtr = 50000;
      const noncePtr = outPtr + len;
      const keyPtr = noncePtr + 12;

      const keyBytes = Buffer.from(keyHex, 'hex');
      const nonceBytes = Buffer.from(nonceHex, 'hex');

      const memView = new Uint8Array(memory.buffer);
      memView.set(nonceBytes, noncePtr);
      memView.set(keyBytes, keyPtr);

      instance.exports.main_test(BigInt(outPtr), BigInt(len), BigInt(noncePtr), BigInt(keyPtr));

      const outputArray = new Uint8Array(memory.buffer, outPtr, len);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for CHACHA20AVX
    if (path.includes('chacha20avx')) {
      const len = Number(process.argv[5]);
      const keyHex = process.argv[6];
      const nonceHex = process.argv[7];

      const outPtr = 50000;
      const noncePtr = outPtr + len;
      const keyPtr = noncePtr + 12;

      const keyBytes = Buffer.from(keyHex, 'hex');
      const nonceBytes = Buffer.from(nonceHex, 'hex');

      const memView = new Uint8Array(memory.buffer);
      memView.set(nonceBytes, noncePtr);
      memView.set(keyBytes, keyPtr);

      instance.exports.main_test(BigInt(outPtr), BigInt(len), BigInt(noncePtr), BigInt(keyPtr));

      const outputArray = new Uint8Array(memory.buffer, outPtr, len);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for CHACHA20XOR-OPT
    if (path.includes('chacha20xor-opt')) {
      const len = Number(process.argv[5]);
      const inputHex = process.argv[6];
      const keyHex   = process.argv[7];
      const nonceHex = process.argv[8];

      const outPtr = 50000;
      const inPtr  = outPtr + len;
      const noncePtr = inPtr + len;
      const keyPtr = noncePtr + 12;

      const inputBytes = Buffer.from(inputHex, 'hex');
      const keyBytes   = Buffer.from(keyHex, 'hex');
      const nonceBytes = Buffer.from(nonceHex, 'hex');

      const memView = new Uint8Array(memory.buffer);
      if (len > 0) memView.set(inputBytes, inPtr);
      memView.set(nonceBytes, noncePtr);
      memView.set(keyBytes, keyPtr);

      instance.exports.main_test(BigInt(outPtr), BigInt(inPtr), BigInt(len), BigInt(noncePtr), BigInt(keyPtr));

      const outputArray = new Uint8Array(memory.buffer, outPtr, len);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for CHACHA20XOR
    if (path.includes('chacha20xor')) {
      const len = Number(process.argv[5]);
      const inputHex = process.argv[6];
      const keyHex   = process.argv[7];
      const nonceHex = process.argv[8];

      const outPtr = 50000;
      const inPtr  = outPtr + len;
      const noncePtr = inPtr + len;
      const keyPtr = noncePtr + 12;

      const inputBytes = Buffer.from(inputHex, 'hex');
      const keyBytes   = Buffer.from(keyHex, 'hex');
      const nonceBytes = Buffer.from(nonceHex, 'hex');

      const memView = new Uint8Array(memory.buffer);
      if (len > 0) memView.set(inputBytes, inPtr);
      memView.set(nonceBytes, noncePtr);
      memView.set(keyBytes, keyPtr);

      instance.exports.main_test(BigInt(outPtr), BigInt(inPtr), BigInt(len), BigInt(noncePtr), BigInt(keyPtr));

      const outputArray = new Uint8Array(memory.buffer, outPtr, len);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for CHACHA20-OPT
    if (path.includes('chacha20-opt')) {
      const len = Number(process.argv[5]);
      const keyHex = process.argv[6];
      const nonceHex = process.argv[7];

      const outPtr = 50000;
      const noncePtr = outPtr + len;
      const keyPtr = noncePtr + 12;

      const keyBytes = Buffer.from(keyHex, 'hex');
      const nonceBytes = Buffer.from(nonceHex, 'hex');

      const memView = new Uint8Array(memory.buffer);
      memView.set(nonceBytes, noncePtr);
      memView.set(keyBytes, keyPtr);

      instance.exports.main_test(BigInt(outPtr), BigInt(len), BigInt(noncePtr), BigInt(keyPtr));

      const outputArray = new Uint8Array(memory.buffer, outPtr, len);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for CHACHA20
    if (path.includes('chacha20')) {
      const len = Number(process.argv[5]);
      const keyHex = process.argv[6];
      const nonceHex = process.argv[7];

      const outPtr = 50000;
      const noncePtr = outPtr + len;
      const keyPtr = noncePtr + 12;

      const keyBytes = Buffer.from(keyHex, 'hex');
      const nonceBytes = Buffer.from(nonceHex, 'hex');

      const memView = new Uint8Array(memory.buffer);
      memView.set(nonceBytes, noncePtr);
      memView.set(keyBytes, keyPtr);

      instance.exports.main_test(BigInt(outPtr), BigInt(len), BigInt(noncePtr), BigInt(keyPtr));

      const outputArray = new Uint8Array(memory.buffer, outPtr, len);
      console.log(Buffer.from(outputArray).toString('hex'));

      return;
    }

    // Special case for GC001
    if (path.includes('gc001')) {
      const x = parseInt(process.argv[5], 10);

      const exports = instance.exports;
      const new_array_i8  = exports.new_array_i8;
      const new_array_i16 = exports.new_array_i16;
      const new_array_i32 = exports.new_array_i32;
      const new_array_i64 = exports.new_array_i64;

      t1 = new_array_i8(0, 32);
      t2 = new_array_i16(0, 16);
      t3 = new_array_i32(0, 8);
      t4 = new_array_i64(BigInt(0), 4);

      [ t1, t2, t3, t4, res ] = instance.exports.main_test(t1, t2, t3, t4, x);

      console.log(res);

      return;
    }

    // Common cases
    const result = instance.exports.main_test(...args);

    if (size === 64) {
      console.log(result.toString());
    }
    else if (size === 32) {
      console.log(result);
    }
    else {
      console.error("Error: Size should be equal to 32 or 64, not to", size);
      process.exit(1);
    }
  }
  catch (err) {
    console.error(err);
  }
}

// Main
const config = parseInputs();
runWasm(config.absolutePath, config.size, config.args);
