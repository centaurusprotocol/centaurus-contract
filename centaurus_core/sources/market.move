module centaurus_core::market {
    use sui::event;
    use sui::bag::{Self, Bag};
    use sui::balance::{Self, Balance, Supply};
    use sui::coin::{Self, Coin};

    use centaurus_core::admin::AdminCap;
    use centaurus_core::pool::{Self, Vault};

    /// `Market` represents the market for wrapped bridged token
    /// where L is the wrapped bridged token type type and C is the bridged token type
    public struct Market<phantom L, phantom C> has key, store {
        id: UID,

        // bit mask of versioned functions
        fun_mask: u256,

        vaults_locked: bool,

        vaults: Bag,
        lp_supply: Supply<L>,
    }

    /// === Events ===
    public struct MarketCreated<phantom C> has copy, drop {
        vaults_parent: ID,
    }

    public struct MarketFunMaskUpdated has copy, drop {
        fun_mask: u256,
    }

    public struct VaultCreated<phantom C> has copy, drop {}

    public struct Wrapped<phantom C> has copy, drop {
        minter: address,
        deposit_amount: u64,
        mint_amount: u64,
    }

    public struct Unwrapped<phantom C> has copy, drop {
        burner: address,
        withdraw_amount: u64,
        burn_amount: u64,
    }

    /// === Tag structs ===
    public struct VaultName<phantom C> has copy, drop, store {}

    // === Errors ===
    // common errors
    const ERR_FUNCTION_VERSION_EXPIRED: u64 = 1;

    // === Internal functions ===

    #[lint_allow(self_transfer)]
    fun pay_from_balance<T>(
        balance: Balance<T>,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        if (balance::value(&balance) > 0) {
            transfer::public_transfer(coin::from_balance(balance, ctx), receiver);
        } else {
            balance::destroy_zero(balance);
        }
    }

    /// === public write functions ===
    // version = 0x1 << 12
    /// wrap bridged token
    public fun wrap_token<L, C>(
        market: &mut Market<L, C>,
        deposit: Coin<C>,
        min_amount_out: u64,
        ctx: &mut TxContext,
    ) {
        assert!(market.fun_mask & 0x1000 == 0, ERR_FUNCTION_VERSION_EXPIRED);

        let minter = tx_context::sender(ctx);
        let deposit_amount = coin::value(&deposit);
        let lp_supply_amount = balance::supply_value(&market.lp_supply);
        let vault: &mut Vault<C> = bag::borrow_mut(&mut market.vaults, VaultName<C> {});

        let mint_amount = pool::wrap(
            vault,
            coin::into_balance(deposit),
            min_amount_out,
            lp_supply_amount,
        );

        // mint to sender
        let minted = balance::increase_supply(&mut market.lp_supply, mint_amount);
        pay_from_balance(minted, minter, ctx);

        // emit deposited
        event::emit(Wrapped<C> {
            minter,
            deposit_amount,
            mint_amount,
        });
    }

    // version = 0x1 << 13
    public fun unwrap_token<L, C>(
        market: &mut Market<L, C>,
        burn: Coin<L>,
        min_amount_out: u64,
        ctx: &mut TxContext,
    ) {
        assert!(market.fun_mask & 0x2000 == 0, ERR_FUNCTION_VERSION_EXPIRED);

        let burner = tx_context::sender(ctx);
        let lp_supply_amount = balance::supply_value(&market.lp_supply);

        let vault: &mut Vault<C> = bag::borrow_mut(&mut market.vaults, VaultName<C> {});

        // burn LP
        let burn_amount = balance::decrease_supply(
            &mut market.lp_supply,
            coin::into_balance(burn),
        );

        // withdraw to burner
        let withdraw = pool::unwrap(
            vault,
            burn_amount,
            min_amount_out,
            lp_supply_amount,
        );

        let withdraw_amount = balance::value(&withdraw);
        pay_from_balance(withdraw, burner, ctx);

        // emit withdrawn
        event::emit(Unwrapped<C> {
            burner,
            withdraw_amount,
            burn_amount,
        });
    }

    // admin functions
    /// create market for centaurus wrapped bridged token and bridged token
    public fun create_market<L, C>(
        _a: &AdminCap,
        lp_supply: Supply<L>,
        ctx: &mut TxContext,
    ) {
        let market = Market<L, C> {
            id: object::new(ctx),
            fun_mask: 0x0,
            vaults_locked: false,
            vaults: bag::new(ctx),
            lp_supply,
        };
        // emit market created
        event::emit(MarketCreated<L> {
            vaults_parent: object::id(&market.vaults),
        });

        transfer::share_object(market);
    }

    public entry fun add_new_vault<L, C>(
        _a: &AdminCap,
        market: &mut Market<L, C>,
    ) {
        let vault = pool::new_vault<C>();
        bag::add(&mut market.vaults, VaultName<C> {}, vault);
        
        // emit vault created
        event::emit(VaultCreated<C> {});
    }

    public entry fun update_market_fun_mask<L, C>(
        _a: &AdminCap,
        market: &mut Market<L, C>,
        fun_mask: u256,
        _ctx: &mut TxContext,
    ) {
        market.fun_mask = fun_mask;
        // emit market fun mask updated
        event::emit(MarketFunMaskUpdated {
            fun_mask: fun_mask,
        });
    }
}