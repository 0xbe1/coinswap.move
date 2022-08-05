.PHONY: build
build:
	aptos move compile --named-addresses coin_swap=default

.PHONY: test
test:
	aptos move test --named-addresses coin_swap=default

.PHONY: deploy
deploy:
	aptos move publish --named-addresses coin_swap=default
