.PHONY: css
css: $(wildcard assets/css/*.scss)
	sassc -t compressed assets/scss/app.scss lib/oban_web/templates/layout/app.css.eex

.PHONY: js
js: assets/js/app.js
	npx parcel build --no-cache --no-source-maps --no-content-hash -d lib/oban_web/templates/layout -o app.js.eex assets/js/app.js

.PHONY: watch
watch: js css watch_loop

.PHONY: watch_loop
watch_loop:
	while true; do \
		fswatch -1 --recursive assets; \
		make css; \
		sleep 1s; \
	done

.PHONY: prepare
prepare:
	brew install fswatch sassc && \
	npm install parcel-bundler && \
	mix deps.get
