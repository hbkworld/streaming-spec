all: streaming.pdf streaming.html

#%.pdf: %.org
#	pandoc -s -S --normalize --toc -N \
#	--latex-engine=xelatex \
#	--variable=papersize:a4paper  \
#	--variable=fontsize:9pt \
#	--template=templates/pdf-confidential-gitinfo.tex \
#	-R -f org $< -o $@

%.pdf: %.md
	pandoc -s -S --normalize -N --toc --toc-depth=2 \
	--latex-engine=xelatex \
	--variable=papersize:a4paper \
	--variable=fontsize:9pt \
	-R -f markdown $< -o $@

%.tex: %.md
	pandoc -s -S --normalize -N --toc --toc-depth=2 \
	--latex-engine=xelatex \
	--variable=papersize:a4paper \
	--variable=fontsize:9pt \
	--template=templates/pdf-confidential-gitinfo.tex \
	-R -f markdown $< -o $@

%.html: %.md
	pandoc -s -S --css=templates/hbm.css --normalize --toc --toc-depth=1 \
	--mathjax \
	-N -R -f markdown $< -o $@


clean:
	rm -f *.epub *.html *.docx *.pdf


#DESTDIR ?= /tmp/cp52

#deploy:
#	cp *.pdf $(DESTDIR)
