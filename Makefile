STYLESHEETS := $(wildcard assets/css/*.scss)

.PHONY: all watch prepare

all: css js

css: $(STYLESHEETS)
	sassc -t compressed assets/scss/app.scss lib/oban_web/templates/layout/app.css.eex

js: assets/js/app.js
	px --no-map --es-syntax-everywhere assets/js/app.js lib/oban_web/templates/layout/app.js.eex

watch:
	bin/watch.sh

prepare:
	brew install sassc && cargo install pax
