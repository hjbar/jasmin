// Globals
import {
  inner_computeFrame_JS,
} from './main.js';


// Computations
self.onmessage = function(e) {
  const { width, height, kernelJS, inputData, outputData } = e.data;

  inner_computeFrame_JS(width, height, kernelJS, inputData, outputData);

  self.postMessage({ outputData }, [outputData.buffer]);
};
