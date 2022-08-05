.PHONY: build
build:
	aptos move compile --named-addresses CoinSwap=default

.PHONY: test
test:
	aptos move test --named-addresses CoinSwap=default

.PHONY: deploy
deploy:
	aptos move publish --named-addresses CoinSwap=default
