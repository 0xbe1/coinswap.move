module NamedAddr::BasicCoin {
    use std::signer;

    struct Coin has store {
        value: u64,
    }

    struct Balance has key {
        coin: Coin
    }

    /// Publish an empty balance resource under `account`'s address. This function must be called before
    /// minting or transferring to the account.
    public fun publish_balance(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<Balance>(addr), 0);
        let empty_coin = Coin { value: 0 };
        move_to(account, Balance { coin: empty_coin });
    }

    #[test(account = @0xC0FFEE)]
    fun test_publish_balance(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance(account);
        assert!(borrow_global<Balance>(addr).coin.value == 0, 0);
    }
}