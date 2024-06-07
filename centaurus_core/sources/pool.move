module centarus_core::pool {
    use std::option::{Self, Option};
    use std::type_name::{Self, TypeName};

    use sui::object::{Self, ID};
    use sui::vec_set::{Self, VecSet};
    use sui::balance::{Self, Balance};

    friend sudo_core::market;

    public(friend) fun wrap<C>(
        vault: &mut Vault<C>,
        fee_model: &RebaseFeeModel,
        price: &AggPrice,
        deposit: Balance<C>,
        min_amount_out: u64,
        lp_supply_amount: u64,
        market_value: Decimal,
        vault_value: Decimal,
        total_vaults_value: Decimal,
        total_weight: Decimal,
    ): (u64, Decimal) {
        assert!(vault.enabled, ERR_VAULT_DISABLED);
        let deposit_amount = balance::value(&deposit);
        assert!(deposit_amount > 0, ERR_INVALID_DEPOSIT_AMOUNT);
        let deposit_value = agg_price::coins_to_value(price, deposit_amount);

        // handle fee
        let fee_rate = compute_rebase_fee_rate(
            fee_model,
            true,
            decimal::add(vault_value, deposit_value),
            decimal::add(total_vaults_value, deposit_value),
            vault.weight,
            total_weight,
        );
        let fee_value = decimal::mul_with_rate(deposit_value, fee_rate);
        deposit_value = decimal::sub(deposit_value, fee_value);

        balance::join(&mut vault.liquidity, deposit);

        // handle mint
        let mint_amount = if (lp_supply_amount == 0) {
            assert!(decimal::is_zero(&market_value), ERR_UNEXPECTED_MARKET_VALUE);
            truncate_decimal(deposit_value)
        } else {
            assert!(!decimal::is_zero(&market_value), ERR_UNEXPECTED_MARKET_VALUE);
            let exchange_rate = decimal::to_rate(
                decimal::div(deposit_value, market_value)
            );
            decimal::floor_u64(
                decimal::mul_with_rate(
                    decimal::from_u64(lp_supply_amount),
                    exchange_rate,
                )
            )
        };
        assert!(mint_amount >= min_amount_out, ERR_AMOUNT_OUT_TOO_LESS);

        (mint_amount, fee_value)
    }

    public(friend) fun unwrap<C>(
        vault: &mut Vault<C>,
        fee_model: &RebaseFeeModel,
        price: &AggPrice,
        burn_amount: u64,
        min_amount_out: u64,
        lp_supply_amount: u64,
        market_value: Decimal,
        vault_value: Decimal,
        total_vaults_value: Decimal,
        total_weight: Decimal,
    ): (Balance<C>, Decimal) {
        assert!(vault.enabled, ERR_VAULT_DISABLED);
        assert!(burn_amount > 0, ERR_INVALID_BURN_AMOUNT);

        let exchange_rate = decimal::to_rate(
            decimal::div(
                decimal::from_u64(burn_amount),
                decimal::from_u64(lp_supply_amount),
            )
        );
        let withdraw_value = decimal::mul_with_rate(market_value, exchange_rate);
        assert!(
            decimal::le(&withdraw_value, &vault_value),
            ERR_INSUFFICIENT_SUPPLY,
        );

        // handle fee
        let fee_rate = compute_rebase_fee_rate(
            fee_model,
            false,
            decimal::sub(vault_value, withdraw_value),
            decimal::sub(total_vaults_value, withdraw_value),
            vault.weight,
            total_weight,
        );
        let fee_value = decimal::mul_with_rate(withdraw_value, fee_rate);
        withdraw_value = decimal::sub(withdraw_value, fee_value);

        let withdraw_amount = decimal::floor_u64(
            agg_price::value_to_coins(price, withdraw_value)
        );
        assert!(
            withdraw_amount <= balance::value(&vault.liquidity),
            ERR_INSUFFICIENT_LIQUIDITY,
        );
        
        let withdraw = balance::split(&mut vault.liquidity, withdraw_amount);
        assert!(
            balance::value(&withdraw) >= min_amount_out,
            ERR_AMOUNT_OUT_TOO_LESS,
        );

        (withdraw, fee_value)
    }
}