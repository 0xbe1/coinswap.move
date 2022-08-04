module CoinSwap::PoolToken {
    use std::signer;
    use BasicCoin::BasicCoin;

    struct PoolToken<phantom CoinType1, phantom CoinType2> {}

    public fun setup_and_mint<CoinType1, CoinType2>(account: &signer, amount: u64) {
        BasicCoin::publish_balance<PoolToken<CoinType1, CoinType2>>(account);
        BasicCoin::mint<PoolToken<CoinType1, CoinType2>>(signer::address_of(account), amount);
    }

    public fun transfer<CoinType1, CoinType2>(from: &signer, to: address, amount: u64) {
        BasicCoin::transfer<PoolToken<CoinType1, CoinType2>>(from, to, amount);
    }

    public fun mint<CoinType1, CoinType2>(mint_addr: address, amount: u64) {
        BasicCoin::mint<PoolToken<CoinType1, CoinType2>>(mint_addr, amount);
    }

    public fun burn<CoinType1, CoinType2>(burn_addr: address, amount: u64) {
        BasicCoin::burn<PoolToken<CoinType1, CoinType2>>(burn_addr, amount);
    }

    //
    // Tests
    //
    #[test_only]
    struct CoinA {}
    struct CoinB {}

    #[test(account = @0x1)]
    fun end_to_end(account: &signer) {
        let addr = signer::address_of(account);
        setup_and_mint<CoinA, CoinB>(account, 10);
        assert!(BasicCoin::balance_of<PoolToken<CoinA, CoinB>>(addr) == 10, 0);
        burn<CoinA, CoinB>(addr, 10);
        assert!(BasicCoin::balance_of<PoolToken<CoinA, CoinB>>(addr) == 0, 0);
    }
}