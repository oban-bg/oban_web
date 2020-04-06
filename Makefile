.PHONY: deploy
deploy:
	cd assets && NODE_ENV=production npx webpack --mode production

.PHONY: watch
watch:
	cd assets && npx webpack --mode development --watch

.PHONY: prepare
prepare:
	mix deps.get && cd assets && npm install
