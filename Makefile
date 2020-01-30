all: streaming.pdf streaming.html complex_types.pdf complex_types.html

#%.pdf: %.org
#	pandoc -s -S --normalize --toc -N \
#	--latex-engine=xelatex \
#	--variable=papersize:a4paper  \
#	--variable=fontsize:9pt \
#	--template=templates/pdf-confidential-gitinfo.tex \
#	-R -f org $< -o $@

%.pdf: %.md
	pandoc -s -N --toc --toc-depth=3 \
	--pdf-engine=xelatex \
	--variable=papersize:a4paper \
	--variable=fontsize:9pt \
	-f markdown $< -o $@

#%.tex: %.md
#	pandoc -s -S --normalize -N --toc --toc-depth=2 \
#	--latex-engine=xelatex \
#	--variable=papersize:a4paper \
#	--variable=fontsize:9pt \
#	--template=templates/pdf-confidential-gitinfo.tex \
#	-R -f markdown $< -o $@

%.html: %.md
	pandoc -s --css=hbm.css --toc --toc-depth=3 \
	--mathjax \
	-N -f markdown $< -o $@


clean:
	rm -f *.epub *.html *.docx *.pdf


#DESTDIR ?= /tmp/cp52

#deploy:
#	cp *.pdf $(DESTDIR)
