MAIN = plots/plot
LATEXMK = latexmk -pdfxe -pdfxelatex="xelatex --interactionmode=nonstop -shell-escape" -bibtex -outdir=plots
EXEC = dune exec src/main.exe -- $(ARG)


all: init format build

init:
	@mkdir -p plots

clean:
	@dune clean
	@latexmk -f -c -outdir=plots $(MAIN).tex > /dev/null
	@rm -f $(MAIN).bbl
	@rm -f $(MAIN).nav
	@rm -f $(MAIN).snm
	@rm -f $(MAIN).vrb

mrproper: clean
	@rm -fR plots/_minted-*
	@rm -f $(MAIN).pdf
	@rm -f $(MAIN).tex
	@rm -f $(MAIN).txt

format:
	@dune fmt

build:
	@dune build

exec: build
	@$(EXEC)

plot: init build
	@$(EXEC) > plots/plot.txt
	@cat plots/helpers/start.txt plots/plot.txt plots/helpers/end.txt > plots/plot.tex
	@$(LATEXMK) $(MAIN).tex

clear:
	@clear
