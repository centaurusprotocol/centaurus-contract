module centarus_core::market {
    use std::option::{Self, Option};
    use std::type_name::{Self, TypeName};

    use sui::event;
    use sui::transfer;
    use sui::bag::{Self, Bag};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::vec_set::{Self, VecSet};
    use sui::vec_map::{Self, VecMap};
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance, Supply};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::sui::{SUI};

    /// === public write functions ===

    // version = 0x1 << 12
    public fun mint_wrapped_token<L, C>(
        market: &mut Market<L>,
        deposit: Coin<C>,
        min_amount_out: u64,
        ctx: &mut TxContext,
    ) {
        assert!(market.fun_mask & 0x1000 == 0, ERR_FUNCTION_VERSION_EXPIRED);

        let minter = tx_context::sender(ctx);
        let deposit_amount = coin::value(&deposit);
        let lp_supply_amount = balance::supply_value(&market.lp_supply);

        let (mint_amount, fee_value) = pool::deposit(
            vault,
            model,
            &price,
            coin::into_balance(deposit),
            min_amount_out,
            lp_supply_amount,
            market_value,
            vault_value,
            total_vaults_value,
            total_weight,
        );

        // mint to sender
        let minted = balance::increase_supply(&mut market.lp_supply, mint_amount);
        pay_from_balance(minted, minter, ctx);

        // emit deposited
        event::emit(Deposited<C> {
            minter,
            price: agg_price::price_of(&price),
            deposit_amount,
            mint_amount,
            fee_value,
        });
    }

    // version = 0x1 << 13
    public fun redeem_wrapped_token<L, C>(
        market: &mut Market<L>,
        burn: Coin<L>,
        min_amount_out: u64,
        ctx: &mut TxContext,
    ) {
        assert!(market.fun_mask & 0x2000 == 0, ERR_FUNCTION_VERSION_EXPIRED);
        assert!(
            object::id(model) == market.rebase_fee_model,
            ERR_MISMATCHED_RESERVING_FEE_MODEL,
        );

        let burner = tx_context::sender(ctx);
        let lp_supply_amount = balance::supply_value(&market.lp_supply);

        let vault: &mut Vault<C> = bag::borrow_mut(&mut market.vaults, VaultName<C> {});

        // burn LP
        let burn_amount = balance::decrease_supply(
            &mut market.lp_supply,
            coin::into_balance(burn),
        );

        // withdraw to burner
        let (withdraw, fee_value) = pool::withdraw(
            vault,
            model,
            &price,
            burn_amount,
            min_amount_out,
            lp_supply_amount,
            market_value,
            vault_value,
            total_vaults_value,
            total_weight,
        );

        let withdraw_amount = balance::value(&withdraw);
        pay_from_balance(withdraw, burner, ctx);

        // emit withdrawn
        event::emit(Withdrawn<C> {
            burner,
            price: agg_price::price_of(&price),
            withdraw_amount,
            burn_amount,
            fee_value,
        });
    }
}