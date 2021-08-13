.PHONY: prepare
prepare:
	mix deps.get && cd assets && npm install

.PHONY: deploy
build:
	cd assets && NODE_ENV=production npx webpack --mode production

.PHONY: watch
watch:
	cd assets && npx webpack --mode development --watch

.PHONY: release
release:
	git push &&
	git push --tags &&
	mix hex.publish package -y &&
	mix hex.build
