# RollFor - SoftRes

The soft-res list for [RollFor](https://github.com/obszczymucha/roll-for-vanilla), as a
RollFor extension.

RollFor itself knows there is *a* soft-res source, or there is not. This addon is what
answers: it owns the list, the name matching, the import window, the `/sr` family and the
minimap contribution, and it registers itself with RollFor as the soft-res source.

What it does **not** know is what a base64 string is. A **provider** addon supplies that:

| Provider | Reads |
|---|---|
| `RollForSoftResIt` | [softres.it](https://softres.it) exports |
| `RollForRaidRes` | [raidres](https://raidres.top) exports |

Install as many as you use. The import window has a Provider dropdown; you pick which site
a pasted string came from, and that is the whole of the difference between them.

## Requirements

RollFor, and at least one provider addon if you want to import anything. The TOC declares
`## Dependencies: RollFor`, so the client loads RollFor first and refuses to load this addon
at all without it.

## Installing

Drop `RollForSoftRes` into `Interface/AddOns`, next to `RollFor`, along with a provider.

## Importing

1. Open your raid on the site you use.
2. Copy the raid's import string.
3. `/sr` in game, pick the provider, paste the string into the box, and hit Import.

`/sr init` clears the list. `/src` checks who in the group has not soft-ressed, `/srs`
shows the reserved items, and `/sro` fixes a player whose in-game name does not match the
name they reserved under.

With no provider installed the window says so and Import is disabled. Your saved list is
left alone -- install the provider again and it comes back at the next login.

## Options

RollFor's options window gets a page for this addon, with the switch to turn it off. Turned
off, RollFor has no soft-res source and its soft-res features go quiet -- nothing else about
RollFor changes. Each provider gets its own page and its own switch; turning a provider off
takes it out of the dropdown after a UI reload.
