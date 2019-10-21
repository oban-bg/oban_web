STYLESHEETS := $(wildcard assets/css/*.scss)

.PHONY: all
all: css js

.PHONY: update_js_deps
update_js_deps:
	cp deps/phoenix/assets/js/phoenix.js assets/js/phoenix.js && \
	cp deps/phoenix_html/priv/static/phoenix_html.js assets/js/phoenix_html.js && \
	cp deps/phoenix_live_view/priv/static/phoenix_live_view.js assets/js/phoenix_live_view.js

.PHONY: css
css: $(STYLESHEETS)
	sassc -t compressed assets/scss/app.scss lib/oban_web/templates/layout/app.css.eex

.PHONY: js
js: assets/js/app.js
	px --no-map --es-syntax-everywhere assets/js/app.js lib/oban_web/templates/layout/app.js.eex

.PHONY: watch
watch: update_js_deps all watch_loop

.PHONY: watch_loop
watch_loop:
	while true; do \
		fswatch -1 --recursive assets; \
		make all; \
		sleep 1s; \
	done

.PHONY: prepare
prepare:
	brew install fswatch sassc && cargo install pax && mix deps.get
