.PHONY: prepare
prepare:
	mix deps.get && npm install --prefix assets

.PHONY: build-css
build-css:
	cd assets && \
		NODE_ENV=production npx tailwindcss --postcss --minify --input css/app.css --output ../priv/static/app.css

.PHONY: build-js
build-js:
	mix esbuild default assets/js/app.js --bundle --minify --outdir=priv/static/

.PHONY: build
build: build-css build-js

.PHONY: watch-css
watch-css:
	cd assets && \
		NODE_ENV=development TAILWIND_MODE=watch npx tailwindcss --postcss --watch --input css/app.css --output ../priv/static/app.css

.PHONY: release
release:
	git push &&
	git push --tags &&
	mix hex.publish package -y &&
	mix hex.build
