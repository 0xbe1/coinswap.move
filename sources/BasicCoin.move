module NamedAddr::BasicCoin {
    struct Coin has key {
        value: u64,
    }

    public fun mint(account: signer, value: u64) {
        move_to(&account, Coin { value })
    }

    #[test(account = @0xC0FFEE)]
    fun test_mint(account: signer) acquires Coin {
        let addr = 0x1::signer::address_of(&account);
        mint(account, 10);
        assert!(borrow_global<Coin>(addr).value == 10, 0);
    }
}