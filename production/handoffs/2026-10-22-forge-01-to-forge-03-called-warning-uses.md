# FORGE-01 → FORGE-03 (cc FORGE-00): Called Warning wording has no seconds

- `config/Support.luau` `calledWarning.uses` is per tier, `{ pledged = 2, empowered = 2 }` for now (empowered 3 pushed two expert Adoring noAutoWin cells over the 70 % bound in the full sweep; FORGE-00 revisits after FL-0146).
- Effect text: `Their first {uses} heavy attacks are telegraphed sooner`; `SupportModel.offers` fills it with a number word, so today it reads "Their first two heavy attacks are telegraphed sooner". No seconds are promised.
- `lead` (0.15 / 0.25 s) is unchanged and is still the `warned` lead the server sends; the client clamps it.
- The modifier given to `DuelModel` carries the resolved number (`uses`), so `DuelModel`/`DuelRunner` read it unchanged.
- FORGE-03: `client/UI/ArenaText.luau` (~line 89) still words the telegraph with seconds; please align it with the offer text.
