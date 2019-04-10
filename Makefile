STYLESHEETS := $(wildcard assets/css/*.scss)

.PHONY: all

all: css js

css: $(STYLESHEETS)
	cd assets && npx node-sass scss/app.scss --output-style=compressed > ../lib/oban_web/templates/layout/app.css.eex; \

js: assets/js/app.js
	cd assets && npx swc js/app.js -o ../lib/oban_web/templates/layout/app.js.eex

.PHONY: watch

watch:
	bin/watch.sh
