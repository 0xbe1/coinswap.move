module NamedAddr::BasicCoin {
    use std::signer;

    /// Address of the owner of this module
    const MODULE_OWNER: address = @NamedAddr;

    /// Error codes
    const ENOT_MODULE_OWNER: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EALREADY_HAS_BALANCE: u64 = 2;

    struct Coin has store {
        value: u64,
    }

    struct Balance has key {
        coin: Coin
    }

    /// Publish an empty balance resource under `account`'s address. This function must be called before
    /// minting or transferring to the account.
    public fun publish_balance(account: &signer) {
        assert!(!exists<Balance>(signer::address_of(account)), EALREADY_HAS_BALANCE);
        let empty_coin = Coin { value: 0 };
        move_to(account, Balance { coin: empty_coin });
    }

    /// Returns the balance of `owner`.
    public fun balance_of(owner: address): u64 acquires Balance {
        borrow_global<Balance>(owner).coin.value
    }

    public fun mint(module_owner: &signer, mint_addr: address, amount: u64) acquires Balance {
        // Only the module owner can initialize this module
        assert!(signer::address_of(module_owner) == MODULE_OWNER, ENOT_MODULE_OWNER);
        deposit(mint_addr, Coin { value: amount});
    }

    /// Transfers `amount` of tokens from `from` to `to`.
    public fun transfer(from: &signer, to: address, amount: u64) acquires Balance {
        let check = withdraw(signer::address_of(from), amount);
        deposit(to, check);
    }

    /// Withdraw `amount` number of tokens from the balance under `addr`.
    fun withdraw(addr: address, amount: u64) : Coin acquires Balance {
        let balance = balance_of(addr);
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);
        let balance_ref = &mut borrow_global_mut<Balance>(addr).coin.value;
        *balance_ref = balance - amount;
        Coin { value: amount }
    }

    /// Deposit `amount` number of tokens to the balance under `addr`.
    fun deposit(addr: address, check: Coin) acquires Balance {
        let Coin { value: amount } = check;
        let balance = balance_of(addr);
        let balance_ref = &mut borrow_global_mut<Balance>(addr).coin.value;
        *balance_ref = balance + amount;
    }

    #[test(account = @0x1)]
    #[expected_failure(abort_code = 2)]
    fun publish_balance_fail_on_exist(account: &signer) {
        // let addr = signer::address_of(account);
        publish_balance(account);
        publish_balance(account);
    }

    #[test(account = @0x1)]
    fun publish_balance_has_zero(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance(account);
        assert!(borrow_global<Balance>(addr).coin.value == 0, 0);
    }

    #[test(account = @0x1)]
    #[expected_failure(abort_code = 0)]
    fun mint_fail_on_non_owner(account: &signer) acquires Balance {
        publish_balance(account);
        assert!(signer::address_of(account) != MODULE_OWNER, 0);
        mint(account, @0x1, 10);
    }

    #[test(account = @NamedAddr)]
    fun mint_ok(account: &signer) acquires Balance {
        publish_balance(account);
        mint(account, @NamedAddr, 10);
        assert!(balance_of(signer::address_of(account)) == 10, 0);
    }

    #[test(account = @0x1)]
    #[expected_failure(abort_code = 1)]
    fun withdraw_fail_on_insufficient_balance(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance(account);
        Coin { value: _ } = withdraw(addr, 10);
    }

    #[test(account = @NamedAddr)]
    fun withdraw_ok(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance(account);
        mint(account, addr, 10);
        let Coin { value: amount } = withdraw(addr, 10);
        assert!(amount == 10, 0);
    }
}