module centaurus_core::pool {
    use sui::balance::{Self, Balance};

    // === Storage ===
    public struct Vault<phantom C> has store {
        enabled: bool,
        last_update: u64,
        liquidity: Balance<C>,
    }

    // === Errors ===
    // vault errors
    const ERR_VAULT_DISABLED: u64 = 1;
    const ERR_INSUFFICIENT_SUPPLY: u64 = 2;
    const ERR_INSUFFICIENT_LIQUIDITY: u64 = 3;

    // deposit, withdraw or swap errors
    const ERR_INVALID_DEPOSIT_AMOUNT: u64 = 4;
    const ERR_INVALID_UNWRAP_AMOUNT: u64 = 5;
    const ERR_AMOUNT_OUT_TOO_LESS: u64 = 6;

    public(package) fun wrap<C>(
        vault: &mut Vault<C>,
        deposit: Balance<C>,
        min_amount_out: u64,
        _lp_supply_amount: u64,
    ): u64 {
        assert!(vault.enabled, ERR_VAULT_DISABLED);
        let deposit_amount = balance::value(&deposit);
        assert!(deposit_amount > 0, ERR_INVALID_DEPOSIT_AMOUNT);

        // deposit coin into vault
        balance::join(&mut vault.liquidity, deposit);

        // mint out the same amount as deposit
        let mint_amount = deposit_amount;
        assert!(mint_amount >= min_amount_out, ERR_AMOUNT_OUT_TOO_LESS);

        mint_amount
    }

    public(package) fun unwrap<C>(
        vault: &mut Vault<C>,
        unwrap_amount: u64,
        min_amount_out: u64,
        lp_supply_amount: u64,
    ): Balance<C> {
        assert!(vault.enabled, ERR_VAULT_DISABLED);
        assert!(unwrap_amount > 0, ERR_INVALID_UNWRAP_AMOUNT);

        assert!(
            unwrap_amount <= lp_supply_amount,
            ERR_INSUFFICIENT_SUPPLY,
        );

        let withdraw_amount = unwrap_amount;
        assert!(
            withdraw_amount <= balance::value(&vault.liquidity),
            ERR_INSUFFICIENT_LIQUIDITY,
        );
        
        let withdraw = balance::split(&mut vault.liquidity, withdraw_amount);
        assert!(
            balance::value(&withdraw) >= min_amount_out,
            ERR_AMOUNT_OUT_TOO_LESS,
        );

        withdraw
    }

    public(package) fun new_vault<C>(): Vault<C> {
        Vault {
            enabled: true,
            last_update: 0,
            liquidity: balance::zero(),
        }
    }
}