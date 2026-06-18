const rawArgs = typeof scriptArgs !== 'undefined' ? scriptArgs : [];
const processArgv = ['firefox-jsagents', 'script.js'].concat(rawArgs);


globalThis.process = {
  argv: processArgv,

  exit: function(code) {
    quit(code);
  },

  hrtime: {
    bigint: function() {
      return BigInt(Math.floor(dateNow() * 1000000));
    }
  }
};


globalThis.Buffer = {
  alloc: function(size, fill) {
    const arr = new Uint8Array(size);
    if (fill !== undefined) arr.fill(fill);
    return arr;
  },

  from: function(inputData, encoding) {
    let uint8;

    if (typeof inputData === 'string') {
      uint8 = new Uint8Array(inputData.length);
      for (let i = 0; i < inputData.length; i++) {
        uint8[i] = inputData.charCodeAt(i) & 0xff;
      }
    } else if (inputData && inputData.buffer) {
      uint8 = new Uint8Array(inputData.buffer);
    } else if (Array.isArray(inputData)) {
      uint8 = new Uint8Array(inputData);
    } else {
      throw new TypeError("Buffer.from : Argument 'inputData' invalid (type: " + typeof inputData + "). ");
    }

    Object.defineProperty(uint8, 'toString', {
      value: function(enc) {
        if (enc === 'hex') {
          return Array.from(this)
                      .map(b => b.toString(16).padStart(2, '0'))
                      .join('');
        }
        return '';
      },

      enumerable: false
    });

    return uint8;
  }
};


Uint8Array.prototype.fill = function(value, encoding) {
  if (encoding === 'hex' && typeof value === 'string') {
    for (let i = 0; i < this.length; i++) {
      const hexSub = value.substr(i * 2, 2);
      if (!hexSub) break;
      this[i] = parseInt(hexSub, 16);
    }
    return this;
  }
  return Array.prototype.fill.call(this, value);
};


globalThis.__dirname = typeof scriptDir !== 'undefined' ? scriptDir.replace(/\/$/, '') : '.';
const dirStack = [globalThis.__dirname];


const modulesCache = {};


globalThis.require = function(modulePath) {
  if (modulePath === 'path') {
    return {
      resolve: function(...args) {
        const parts = args.filter(p => p && p !== '.');
        return parts.join('/');
      }
    };
  }

  if (modulePath === 'fs') {
    return {
      readFileSync: function(filePath) {
        let cleanPath = filePath.replace(/^\.\//, '').replace(/\/+/g, '/');
        const currentDir = dirStack[dirStack.length - 1] || '.';

        if (!cleanPath.startsWith(currentDir) && currentDir !== '.') {
          cleanPath = currentDir + '/' + cleanPath;
        } else if (cleanPath.startsWith('prog/') && typeof globalThis.__currentAlgoDir !== 'undefined') {
          cleanPath = globalThis.__currentAlgoDir + '/' + cleanPath;
        }

        cleanPath = cleanPath.replace(/^\.\//, '');

        try {
          const rawData = read(cleanPath, 'binary');

          if (typeof rawData === 'string') {
            const arr = new Uint8Array(rawData.length);
            for (let i = 0; i < rawData.length; i++) {
              arr[i] = rawData.charCodeAt(i) & 0xff;
            }
            return arr;
          }

          return new Uint8Array(rawData.buffer || rawData);
        } catch(e) {
          throw new Error("SpiderMonkey didn't handle the file : " + cleanPath + " (Error: " + e.message + ")");
        }
      }
    };
  }

  if (modulePath === 'buffer') {
    return { Buffer: globalThis.Buffer };
  }

  const currentDir = dirStack[dirStack.length - 1];
  let resolvedPath = modulePath;
  if (modulePath.startsWith('.')) {
    resolvedPath = currentDir + '/' + modulePath;
  }
  if (!resolvedPath.endsWith('.js')) {
    resolvedPath += '.js';
  }

  while (resolvedPath.includes('../')) {
    resolvedPath = resolvedPath.replace(/[^\/]+\/\.\.\//, '');
  }

  if (modulesCache[resolvedPath]) {
    return modulesCache[resolvedPath];
  }

  const nextDir = resolvedPath.substring(0, resolvedPath.lastIndexOf('/'));

  const oldDirname = globalThis.__dirname;
  globalThis.__dirname = nextDir;
  dirStack.push(nextDir);

  globalThis.module = { exports: {} };
  globalThis.exports = globalThis.module.exports;

  const fileContent = read(resolvedPath);
  const moduleRunner = new Function('exports', 'require', 'module', '__filename', '__dirname', fileContent);
  moduleRunner(globalThis.exports, globalThis.require, globalThis.module, resolvedPath, nextDir);

  const exportedValue = globalThis.module.exports;
  modulesCache[resolvedPath] = exportedValue;

  dirStack.pop();
  globalThis.__dirname = oldDirname;

  return exportedValue;
};
