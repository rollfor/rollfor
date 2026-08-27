# RollFor - SR Provider (softres.it)

The softres.it import format for
[RollFor](https://github.com/obszczymucha/roll-for-vanilla)'s SoftRes addon, as a RollFor
extension.

This addon is a **data provider**. `RollForSoftRes` owns the soft-res list, the import
window, the name matching, `/sr` and everything RollFor asks about who reserved what; the
one thing it has no opinion about is what a base64 string means. That is this addon, and
it is four files.

It creates no frames, claims no slash commands and holds no data.

## Requirements

`RollFor` and `RollForSoftRes`. The TOC declares
`## Dependencies: RollFor, RollForSoftRes`, so the client loads the chain in that order and
refuses to load this addon without both. RollFor is named as well as implied by the library,
so unticking it in the addon list greys this one out too.

## Installing

Drop `RollForSoftResIt` into `Interface/AddOns`, next to `RollForSoftRes` and `RollFor`.

`RollForRaidRes` can be installed at the same time -- that is the point of the split. Both
appear in the import window's Provider dropdown and you pick per import. (Before the split
the two addons each carried a whole copy of the soft-res addon and were mutually
exclusive.)

## Importing

1. Open your raid on [softres.it](https://softres.it).
2. Copy the raid's import string.
3. `/sr` in game, pick **softres.it** in the Provider dropdown, paste the string, and hit
   Import.

A softres.it export is base64 over *zlib* over JSON. A raidres string is plain base64 over
JSON, which this provider does not read -- pasting one with softres.it selected reports that
the data could not be loaded, and naming the provider in that message is how you know which
half of the mistake to fix.

`LibDeflate` does the decompression and comes from RollFor, so this addon does not ship it.

## Your existing data

Nothing is carried over from any earlier version. `RollForSoftRes` starts with an empty
list and your manual `/sro` name matches are not migrated either -- paste your string
again, and redo any name overrides. The old saved variables are left in place rather than
deleted, so nothing is destroyed.

## Options

RollFor's options window gets a page for this addon, with the switch to turn it off. Turned
off, softres.it leaves the Provider dropdown at the next UI reload. A list already imported
with it is left exactly where it is.
