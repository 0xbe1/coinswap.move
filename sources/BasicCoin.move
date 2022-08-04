module NamedAddr::BasicCoin {
    use std::signer;

    /// Address of the owner of this module
    const MODULE_OWNER: address = @NamedAddr;

    /// Error codes
    const ENOT_MODULE_OWNER: u64 = 0;
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

    public fun mint<CoinType>(module_owner: &signer, mint_addr: address, amount: u64) acquires Balance {
        // Only the module owner can initialize this module
        assert!(signer::address_of(module_owner) == MODULE_OWNER, ENOT_MODULE_OWNER);
        deposit<CoinType>(mint_addr, Coin<CoinType> { value: amount});
    }

    /// Transfers `amount` of tokens from `from` to `to`.
    public fun transfer<CoinType>(from: &signer, to: address, amount: u64) acquires Balance {
        let from_addr = signer::address_of(from);
        assert!(from_addr != to, EEQUAL_ADDR);
        let check = withdraw<CoinType>(signer::address_of(from), amount);
        deposit<CoinType>(to, check);
    }

    /// Withdraw `amount` number of tokens from the balance under `addr`.
    fun withdraw<CoinType>(addr: address, amount: u64) : Coin<CoinType> acquires Balance {
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
        // let addr = signer::address_of(account);
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
    #[expected_failure(abort_code = 0)]
    fun mint_fail_on_non_owner(account: &signer) acquires Balance {
        publish_balance<TestCoin>(account);
        assert!(signer::address_of(account) != MODULE_OWNER, 0);
        mint<TestCoin>(account, @0x1, 10);
    }

    #[test(account = @NamedAddr)]
    fun mint_ok(account: &signer) acquires Balance {
        publish_balance<TestCoin>(account);
        mint<TestCoin>(account, @NamedAddr, 10);
        assert!(balance_of<TestCoin>(signer::address_of(account)) == 10, 0);
    }

    #[test(account = @0x1)]
    #[expected_failure(abort_code = 1)]
    fun withdraw_fail_on_insufficient_balance(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance<TestCoin>(account);
        Coin { value: _ } = withdraw<TestCoin>(addr, 10);
    }

    #[test(account = @NamedAddr)]
    fun withdraw_ok(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance<TestCoin>(account);
        mint<TestCoin>(account, addr, 10);
        let Coin { value: amount } = withdraw<TestCoin>(addr, 10);
        assert!(amount == 10, 0);
    }
}