// initializer for centaurus module
module centaurus_core::initializer {
    use centaurus_core::admin::create_admin_cap;
    // create an admin cap
    fun init(ctx: &mut TxContext) {
        create_admin_cap(ctx);
    }
}
