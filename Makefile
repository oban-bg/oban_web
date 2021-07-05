.PHONY: prepare
prepare:
	mix deps.get && cd assets && npm install

.PHONY: build
build:
	cd assets && \
		NODE_ENV=production npx webpack --mode production && \
		rm ../priv/static/js/app.js.LICENSE.txt

.PHONY: watch
watch:
	cd assets && npx webpack --mode development --watch

.PHONY: release
release:
	git push &&
	git push --tags &&
	mix hex.publish package -y &&
	mix hex.build
