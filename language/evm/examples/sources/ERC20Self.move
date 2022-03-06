#[eth_contract]
/// An implementation of the ERC-20 Token Standard.
module Evm::ERC20_ALT {
    use Evm::Evm::{sender, emit};
    use Evm::Table::{Self, Table};
    use Evm::U256::{Self, U256};
    use Std::ASCII::{String};
    use Std::Errors;

    #[eth_event]
    struct Transfer {
        from: address,
        to: address,
        value: U256,
    }

    #[eth_event]
    struct Approval {
        owner: address,
        spender: address,
        value: U256,
    }

    #[eth_storage]
    /// Represents the state of this contract. This is located at `borrow_global<State>(self())`.
    struct State has key {
        balances: Table<address, U256>,
        allowances: Table<address, Table<address, U256>>,
        total_supply: U256,
        name: String,
        symbol: String,
    }

    #[eth_create]
    /// Constructor of this contract.
    public fun create(name: String, symbol: String): State {
        State {
            total_supply: U256::zero(),
            balances: Table::empty<address, U256>(),
            allowances: Table::empty<address, Table<address, U256>>(),
            name,
            symbol,
       }
    }

    #[eth_callable]
    /// Returns the name of the token
    public fun name(self: &State): String {
        self.name
    }

    #[eth_callable]
    /// Returns the symbol of the token, usually a shorter version of the name.
    public fun symbol(self: &State): String {
        self.symbol
    }

    #[eth_callable]
    /// Returns the number of decimals used to get its user representation.
    public fun decimals(_self: &State): u8 {
        18
    }

    #[eth_callable]
    /// Returns the total supply of the token.
    public fun totalSupply(self: &State): U256
        self.total_supply
    }

    #[eth_callable]
    /// Returns the balance of an account.
    public fun balanceOf(self: &State, owner: address): U256 {
        *mut_balanceOf(self, owner)
    }

    #[eth_callable]
    /// Transfers the amount from the sending account to the given account
    public fun transfer(self: &mut State, to: address, amount: U256): bool {
        assert!(sender() != to, Errors::invalid_argument(0));
        do_transfer(self, sender(), to, amount);
        true
    }

    #[eth_callable]
    /// Transfers the amount on behalf of the `from` account to the given account.
    /// This evaluates and adjusts the allowance.
    public fun transferFrom(self: &mut State, from: address, to: address, amount: U256): bool {
        assert!(sender() != to, Errors::invalid_argument(0));
        let allowance_for_sender = mut_allowance(self, from, sender());
        assert!(U256::le(copy amount, *allowance_for_sender), Errors::limit_exceeded(0));
        *allowance_for_sender = U256::sub(*allowance_for_sender, copy amount);
        do_transfer(self, from, to, amount);
        true
    }

    #[eth_callable]
    /// Approves that the spender can spent the given amount on behalf of the calling account.
    public fun approve(self: &mut State, spender: address, amount: U256): bool {
        if(!Table::contains(&self.allowances, &sender())) {
            Table::insert(&mut self.allowances, sender(), Table::empty<address, U256>())
        };
        let a = Table::borrow_mut(&mut self.allowances, &sender());
        Table::insert(a, spender, copy amount);
        emit(Approval{owner: sender(), spender, value: amount});
        true
    }

    #[eth_callable]
    /// Returns the allowance an account owner has approved for the given spender.
    public fun allowance(self: &mut State, owner: address, spender: address): U256 {
        *mut_allowance(self, owner, spender)
    }

    /// Helper function to perform a transfer of funds.
    fun do_transfer(self: &mut State, from: address, to: address, amount: U256) {
        let from_bal = mut_balanceOf(self, from);
        assert!(U256::le(copy amount, *from_bal), Errors::limit_exceeded(0));
        *from_bal = U256::sub(*from_bal, copy amount);
        let to_bal = mut_balanceOf(self, to);
        *to_bal = U256::add(*to_bal, copy amount);
        emit(Transfer{from, to, value: amount});
    }

    /// Helper function to return a mut ref to the allowance of a spender.
    fun mut_allowance(self: &mut State, owner: address, spender: address): &mut U256 {
        if(!Table::contains(&self.allowances, &owner)) {
            Table::insert(&mut self.allowances, owner, Table::empty<address, U256>())
        };
        let allowance_owner = Table::borrow_mut(&mut self.allowances, &owner);
        Table::borrow_mut_with_default(allowance_owner, spender, U256::zero())
    }

    /// Helper function to return a mut ref to the balance of a owner.
    fun mut_balanceOf(self: &mut State, owner: address): &mut U256 {
        Table::borrow_mut_with_default(&mut self.balances, owner, U256::zero())
    }
}
