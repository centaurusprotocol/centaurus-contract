module ct_usdt::ct_usdt {
    use sui::coin;

    public struct CT_USDT has drop {}

    fun init(witness: CT_USDT, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            6,
            b"ctUSDT",
            b"Centaurus Wrapped Token for Eth Brideged Usdt.",
            b"Centaurus Wrapped Token for Eth Brideged Usdt.",
            option::none(),
            ctx,
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }
}