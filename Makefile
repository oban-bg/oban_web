STYLESHEETS := $(wildcard assets/css/*.scss)

.PHONY: all watch prepare

all: css js

css: $(STYLESHEETS)
	sassc -t compressed assets/scss/app.scss lib/oban_web/templates/layout/app.css.eex

js: assets/js/app.js
	px --no-map --es-syntax-everywhere assets/js/app.js lib/oban_web/templates/layout/app.js.eex

watch: all watch_loop

watch_loop:
	while true; do \
		fswatch -1 --recursive assets; \
		make all; \
		sleep 1s; \
	done

prepare:
	brew install fswatch sassc && cargo install pax
