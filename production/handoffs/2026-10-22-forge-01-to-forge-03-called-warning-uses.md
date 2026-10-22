# FORGE-01 → FORGE-03 (cc FORGE-00): Called Warning covers 2 / 3 heavy attacks, text has no seconds

- `config/Support.luau` `calledWarning.uses` is now per tier: `{ pledged = 2, empowered = 3 }`.
- Effect text is now `Their first {uses} heavy attacks are telegraphed sooner`; `SupportModel.offers` fills `{uses}` for the offered power (e.g. "Their first 3 heavy attacks are telegraphed sooner"). No seconds are promised.
- `lead` (0.15 / 0.25 s) is unchanged and still the `warned` lead the server sends; the client clamps it.
- The modifier handed to `DuelModel` carries the resolved number (`uses = 2|3`), so `DuelModel`/`DuelRunner` read it unchanged.
- FORGE-03: `client/UI/ArenaText.luau` (~line 89) still words the telegraph with seconds; please align it with the offer text above.
