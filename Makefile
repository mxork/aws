PACKAGENAME=aws
COLLECTS=aws
SCRBL=aws/aws.scrbl

all: setup

clean:
	find . -name compiled -type d | xargs rm -rf
	rm -rf htmldocs

setup:
	raco setup --tidy --avoid-main $(COLLECTS)

link:
	raco pkg install --link -n $(PACKAGENAME) $$(pwd)

unlink:
	raco pkg remove $(PACKAGENAME)

test:
	raco test -x .

htmldocs: $(SCRBL)
	raco scribble \
		--html \
		--dest htmldocs \
		--dest-name index \
		++main-xref-in \
		--redirect-main http://docs.racket-lang.org/ \
		\
		$(SCRBL)
