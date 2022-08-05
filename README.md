# coinswap.move

A minimal DEX (Uniswap V2 like) in Move, where:

- Most public functions are tested.
- BasicCoin.move is adopted from [Move tutorial](https://github.com/move-language/move/tree/main/language/documentation/tutorial).
- CoinSwap.move and PoolToken.move are adopted from [Move examples](https://github.com/move-language/move/tree/main/language/documentation/examples/experimental/coin-swap).

## Deploy on Aptos

Prerequisite: install Aptos CLI.

Create an account:

```
aptos init
```

Deploy:

```
make deploy
```

Get account address:

```
aptos account list | grep self_address
```

Check account info:

```
aptos account list
```

Check account info on explorer:

https://explorer.devnet.aptos.dev/account/88573bd61120de335d820efe8161f9f0ae95dfa7f6856e3f93ce72d42bb5b5e9
