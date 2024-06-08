module centaurus_core::admin {
    public struct AdminCap has key {
        id: UID,
    }

    #[lint_allow(self_transfer)]
    public(package) fun create_admin_cap(ctx: &mut TxContext) {
        let admin_cap = AdminCap { id: object::new(ctx) };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }
}