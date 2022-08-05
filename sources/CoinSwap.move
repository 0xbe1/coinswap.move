module coin_swap::CoinSwap {
    use std::signer;
    use coin_swap::BasicCoin;
    use coin_swap::PoolToken;

    const ECOINSWAP_ADDRESS: u64 = 0;
    const EPOOL: u64 = 1;

    struct LiquidityPool<phantom CoinType1, phantom CoinType2> has key {
        coin1: u64,
        coin2: u64,
        share: u64,
    }

    public fun create_pool<CoinType1: drop, CoinType2: drop>(
        coinswap: &signer,
        requester: &signer,
        coin1: u64,
        coin2: u64,
        share: u64,
        // witness1: CoinType1,
        // witness2: CoinType2
    ) {
        assert!(signer::address_of(coinswap) == @coin_swap, ECOINSWAP_ADDRESS);
        assert!(!exists<LiquidityPool<CoinType1, CoinType2>>(signer::address_of(coinswap)), EPOOL);

        // TODO: Alternatively, `struct LiquidityPool` could be refactored to actually hold the coin (e.g., coin1: CoinType1).
        if (!BasicCoin::has_balance<CoinType1>(coinswap)) {
            BasicCoin::publish_balance<CoinType1>(coinswap);
        };
        if (!BasicCoin::has_balance<CoinType2>(coinswap)) {
            BasicCoin::publish_balance<CoinType2>(coinswap);
        };
        move_to(coinswap, LiquidityPool<CoinType1, CoinType2>{coin1, coin2, share});

        // Transfer the initial liquidity of CoinType1 and CoinType2 to the pool under @coin_swap.
        BasicCoin::transfer<CoinType1>(requester, signer::address_of(coinswap), coin1);
        BasicCoin::transfer<CoinType2>(requester, signer::address_of(coinswap), coin2);

        // Mint PoolToken and deposit it in the account of requester.
        PoolToken::setup_and_mint<CoinType1, CoinType2>(requester, share);
    }

    public fun swap<CoinType1: drop, CoinType2: drop>(
        coinswap: &signer,
        requester: &signer,
        coin1: u64,
        // witness1: CoinType1,
        // witness2: CoinType2
    ) acquires LiquidityPool {
        assert!(signer::address_of(coinswap) == @coin_swap, ECOINSWAP_ADDRESS);
        assert!(exists<LiquidityPool<CoinType1, CoinType2>>(signer::address_of(coinswap)), EPOOL);
        let pool = borrow_global_mut<LiquidityPool<CoinType1, CoinType2>>(signer::address_of(coinswap));
        let coin2 = get_input_price(coin1, pool.coin1, pool.coin2);
        pool.coin1 = pool.coin1 + coin1;
        pool.coin2 = pool.coin2 - coin2;

        BasicCoin::transfer<CoinType1>(requester, signer::address_of(coinswap), coin1);
        BasicCoin::transfer<CoinType2>(coinswap, signer::address_of(requester), coin2);
    }

    public fun add_liquidity<CoinType1: drop, CoinType2: drop>(
        account: &signer,
        coin1: u64,
        coin2: u64,
        // witness1: CoinType1,
        // witness2: CoinType2,
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool<CoinType1, CoinType2>>(@coin_swap);

        let coin1_added = coin1;
        let share_minted = (coin1_added * pool.share) / pool.coin1;
        let coin2_added = (share_minted * pool.coin2) / pool.share;

        pool.coin1 = pool.coin1 + coin1_added;
        pool.coin2 = pool.coin2 + coin2_added;
        pool.share = pool.share + share_minted;

        BasicCoin::transfer<CoinType1>(account, @coin_swap, coin1);
        BasicCoin::transfer<CoinType2>(account, @coin_swap, coin2);
        PoolToken::mint<CoinType1, CoinType2>(signer::address_of(account), share_minted)
    }

    public fun remove_liquidity<CoinType1: drop, CoinType2: drop>(
        coinswap: &signer,
        requester: &signer,
        share: u64,
        // witness1: CoinType1,
        // witness2: CoinType2,
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool<CoinType1, CoinType2>>(@coin_swap);

        let coin1_removed = (pool.coin1 * share) / pool.share;
        let coin2_removed = (pool.coin2 * share) / pool.share;

        pool.coin1 = pool.coin1 - coin1_removed;
        pool.coin2 = pool.coin2 - coin2_removed;
        pool.share = pool.share - share;

        BasicCoin::transfer<CoinType1>(coinswap, signer::address_of(requester), coin1_removed);
        BasicCoin::transfer<CoinType2>(coinswap, signer::address_of(requester), coin2_removed);
        PoolToken::burn<CoinType1, CoinType2>(signer::address_of(requester), share)
    }

    /// (x+0.997dx)(y-dy)=xy => dy=(997dx*y)/(1000x+997dx)
    fun get_input_price(input_amount: u64, input_reserve: u64, output_reserve: u64): u64 {
        let input_amount_with_fee = input_amount * 997;
        let numerator = input_amount_with_fee * output_reserve;
        let denominator = (input_reserve * 1000) + input_amount_with_fee;
        numerator / denominator
    }

    //
    // Tests
    //
    #[test_only]
    struct CoinA has drop {}

    #[test_only]
    struct CoinB has drop {}

    #[test_only]
    struct CoinC has drop {}

    #[test(coinswap = @0x1, requester = @0x1)]
    #[expected_failure(abort_code = 0)]
    fun create_pool_non_coinswap(coinswap: &signer, requester: &signer) {
        create_pool<CoinA, CoinB>(coinswap, requester, 10, 10, 1);
    }

    #[test(coinswap = @coin_swap, requester = @0x1)]
    fun create_pools_ok(coinswap: &signer, requester: &signer) {
        BasicCoin::setup_and_mint<CoinA>(requester, 100);
        BasicCoin::setup_and_mint<CoinB>(requester, 100);
        BasicCoin::setup_and_mint<CoinC>(requester, 100);

        create_pool<CoinA, CoinB>(coinswap, requester, 10, 10, 1);
        create_pool<CoinA, CoinC>(coinswap, requester, 10, 10, 1);
    }

    #[test(coinswap = @coin_swap, requester = @0x1)]
    fun create_pool_ok(coinswap: &signer, requester: &signer) acquires LiquidityPool {
        BasicCoin::setup_and_mint<CoinA>(requester, 100);
        BasicCoin::setup_and_mint<CoinB>(requester, 100);

        create_pool<CoinA, CoinB>(coinswap, requester, 10, 10, 1);

        // coinswap owns the liquidity pool
        assert!(borrow_global<LiquidityPool<CoinA, CoinB>>(signer::address_of(coinswap)).share == 1, 0);
        // requester owns the pool token
        let requester_addr = signer::address_of(requester);
        assert!(PoolToken::balance_of<CoinA, CoinB>(requester_addr) == 1, 0);
        // requester has less basic coin
        assert!(BasicCoin::balance_of<CoinA>(requester_addr) == 90, 0);
        assert!(BasicCoin::balance_of<CoinB>(requester_addr) == 90, 0);
    }

    #[test(coinswap = @coin_swap, requester = @0x1)]
    fun add_liquidity_ok(coinswap: &signer, requester: &signer) acquires LiquidityPool {
        BasicCoin::setup_and_mint<CoinA>(requester, 100);
        BasicCoin::setup_and_mint<CoinB>(requester, 100);

        create_pool<CoinA, CoinB>(coinswap, requester, 10, 10, 1);
        add_liquidity<CoinA, CoinB>(requester, 90, 90);

        // liquidity pool state
        let lp = borrow_global<LiquidityPool<CoinA, CoinB>>(signer::address_of(coinswap));
        assert!(lp.coin1 == 100, 0);
        assert!(lp.coin2 == 100, 0);
        assert!(lp.share == 10, 0);

        // requester state
        let requester_addr = signer::address_of(requester);
        assert!(BasicCoin::balance_of<CoinA>(requester_addr) == 0, 0);
        assert!(BasicCoin::balance_of<CoinB>(requester_addr) == 0, 0);
        assert!(PoolToken::balance_of<CoinA, CoinB>(requester_addr) == 10, 0)
    }

    #[test(coinswap = @coin_swap, requester = @0x1)]
    fun remove_liquidity_ok(coinswap: &signer, requester: &signer) acquires LiquidityPool {
        BasicCoin::setup_and_mint<CoinA>(requester, 100);
        BasicCoin::setup_and_mint<CoinB>(requester, 100);

        create_pool<CoinA, CoinB>(coinswap, requester, 100, 100, 10);
        remove_liquidity<CoinA, CoinB>(coinswap, requester, 9);

        // liquidity pool state
        let lp = borrow_global<LiquidityPool<CoinA, CoinB>>(signer::address_of(coinswap));
        assert!(lp.coin1 == 10, 0);
        assert!(lp.coin2 == 10, 0);
        assert!(lp.share == 1, 0);

        // requester state
        let requester_addr = signer::address_of(requester);
        assert!(BasicCoin::balance_of<CoinA>(requester_addr) == 90, 0);
        assert!(BasicCoin::balance_of<CoinB>(requester_addr) == 90, 0);
        assert!(PoolToken::balance_of<CoinA, CoinB>(requester_addr) == 1, 0)
    }

    #[test]
    fun get_input_price_ok() {
        assert!(get_input_price(10, 100, 100) == 9, 0)
    }
}