SAMPLES ?= 10
REPEAT ?= 8750

COMPILER_DIR=../../..
COMPILER=$(COMPILER_DIR)/jasminc
REFLECT=.
WASM_OPTIONS=--all-features
WASM_AS=wasm-as $(WASM_OPTIONS)
WASM_OPT3=wasm-opt -O3 $(WASM_OPTIONS)
WASM_OPT4=wasm-opt -O4 $(WASM_OPTIONS)
LOG_DIR=logs
MAKE_OPTIONS=--no-print-directory


all: build_wasm_as

install_node_modules:
	@npm install fluent-ffmpeg @ffmpeg-installer/ffmpeg --silent

build_compiler:
	@$(MAKE) $(MAKE_OPTIONS) -C $(COMPILER_DIR) > /dev/null

build_jasmin: build_compiler
	@OCAMLRUNPARAM=b $(COMPILER) -arch wasm $(REFLECT)/main_ref.jazz -o $(REFLECT)/main_ref.wat
	@OCAMLRUNPARAM=b $(COMPILER) -arch wasm $(REFLECT)/main_vec.jazz -o $(REFLECT)/main_vec.wat
	@OCAMLRUNPARAM=b $(COMPILER) -arch wasm $(REFLECT)/main_opt.jazz -o $(REFLECT)/main_opt.wat

build_wasm_as: build_jasmin
	@$(WASM_AS) $(REFLECT)/main_ref.wat -o $(REFLECT)/main_ref.wasm
	@$(WASM_AS) $(REFLECT)/main_vec.wat -o $(REFLECT)/main_vec.wasm
	@$(WASM_AS) $(REFLECT)/main_opt.wat -o $(REFLECT)/main_opt.wasm

build_wasm_opt3: build_jasmin
	@$(WASM_OPT3) $(REFLECT)/main_ref.wat -o $(REFLECT)/main_ref.wasm
	@$(WASM_OPT3) $(REFLECT)/main_vec.wat -o $(REFLECT)/main_vec.wasm
	@$(WASM_OPT3) $(REFLECT)/main_opt.wat -o $(REFLECT)/main_opt.wasm

build_wasm_opt4: build_jasmin
	@$(WASM_OPT4) $(REFLECT)/main_ref.wat -o $(REFLECT)/main_ref.wasm
	@$(WASM_OPT4) $(REFLECT)/main_vec.wat -o $(REFLECT)/main_vec.wasm
	@$(WASM_OPT4) $(REFLECT)/main_opt.wat -o $(REFLECT)/main_opt.wasm

bench: install_node_modules
	@mkdir -p $(LOG_DIR)
	@(\
		echo "\n\n===== Benchmark with Wasm-as =====\n" && \
		$(MAKE) $(MAKE_OPTIONS) build_wasm_as && \
		taskset --cpu-list 0 node benchmark.js video.mp4 $(SAMPLES) $(REPEAT) && \
		echo "\n\n===== Benchmark with Wasm-opt -O3 =====\n" && \
		$(MAKE) $(MAKE_OPTIONS) build_wasm_opt3 && \
		taskset --cpu-list 0 node benchmark.js video.mp4 $(SAMPLES) $(REPEAT) && \
		echo "\n\n===== Benchmark with Wasm-opt -O4 =====\n" && \
		$(MAKE) $(MAKE_OPTIONS) build_wasm_opt4 && \
		taskset --cpu-list 0 node benchmark.js video.mp4 $(SAMPLES) $(REPEAT) \
	) | tee $(LOG_DIR)/log_$(SAMPLES)_$(REPEAT).txt

server:
	@python3 -m http.server 9000

clean:
	@rm -rf *.wat
	@rm -rf *.wasm

mrproper: clean
	@rm -rf node_modules
	@rm -rf package.json
	@rm -rf package-lock.json

clean_logs:
	@rm -rf logs
