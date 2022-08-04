module BasicCoin::BasicCoin {
    use std::signer;

    /// Error codes
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EALREADY_HAS_BALANCE: u64 = 2;
    const EEQUAL_ADDR: u64 = 3;

    struct Coin<phantom CoinType> has store {
        value: u64,
    }

    struct Balance<phantom CoinType> has key {
        coin: Coin<CoinType>
    }

    /// Publish an empty balance resource under `account`'s address. This function must be called before
    /// minting or transferring to the account.
    public fun publish_balance<CoinType>(account: &signer) {
        assert!(!exists<Balance<CoinType>>(signer::address_of(account)), EALREADY_HAS_BALANCE);
        let empty_coin = Coin<CoinType> { value: 0 };
        move_to(account, Balance<CoinType> { coin: empty_coin });
    }

    /// Returns the balance of `owner`.
    public fun balance_of<CoinType>(owner: address): u64 acquires Balance {
        borrow_global<Balance<CoinType>>(owner).coin.value
    }

    public fun mint<CoinType>(mint_addr: address, amount: u64) acquires Balance {
        deposit<CoinType>(mint_addr, Coin<CoinType> { value: amount});
    }

    public fun burn<CoinType>(burn_addr: address, amount: u64) acquires Balance {
        let Coin { value: _ } = withdraw<CoinType>(burn_addr, amount);
    }

    /// Transfers `amount` of tokens from `from` to `to`.
    public fun transfer<CoinType>(from: &signer, to: address, amount: u64) acquires Balance {
        let from_addr = signer::address_of(from);
        assert!(from_addr != to, EEQUAL_ADDR);
        let check = withdraw<CoinType>(signer::address_of(from), amount);
        deposit<CoinType>(to, check);
    }

    /// Withdraw `amount` number of tokens from the balance under `addr`.
    fun withdraw<CoinType>(addr: address, amount: u64): Coin<CoinType> acquires Balance {
        let balance = balance_of<CoinType>(addr);
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);
        let balance_ref = &mut borrow_global_mut<Balance<CoinType>>(addr).coin.value;
        *balance_ref = balance - amount;
        Coin<CoinType> { value: amount }
    }

    /// Deposit `amount` number of tokens to the balance under `addr`.
    fun deposit<CoinType>(addr: address, check: Coin<CoinType>) acquires Balance {
        let Coin { value: amount } = check;
        let balance = balance_of<CoinType>(addr);
        let balance_ref = &mut borrow_global_mut<Balance<CoinType>>(addr).coin.value;
        *balance_ref = balance + amount;
    }

    //
    // Tests
    //
    #[test_only]
    struct TestCoin {}

    #[test(account = @0x1)]
    #[expected_failure(abort_code = 2)]
    fun publish_balance_fail_on_exist(account: &signer) {
        publish_balance<TestCoin>(account);
        publish_balance<TestCoin>(account);
    }

    #[test(account = @0x1)]
    fun publish_balance_has_zero(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance<TestCoin>(account);
        assert!(borrow_global<Balance<TestCoin>>(addr).coin.value == 0, 0);
    }

    #[test(account = @0x1)]
    fun mint_ok(account: &signer) acquires Balance {
        publish_balance<TestCoin>(account);
        mint<TestCoin>(@0x1, 10);
        assert!(balance_of<TestCoin>(signer::address_of(account)) == 10, 0);
    }

    #[test(account = @0x1)]
    #[expected_failure(abort_code = 1)]
    fun burn_fail_on_insufficient_balance(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance<TestCoin>(account);
        burn<TestCoin>(addr, 10);
    }

    #[test(account = @0x1)]
    fun burn_ok(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance<TestCoin>(account);
        mint<TestCoin>(addr, 10);
        assert!(balance_of<TestCoin>(addr) == 10, 0);
        burn<TestCoin>(addr, 10);
        assert!(balance_of<TestCoin>(addr) == 0, 0);
    }
}