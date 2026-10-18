# Invoice Maker (Slice of Life Ltd)

iOS + iPad invoice, estimate and receipt maker by Slice of Life Ltd. The spec and strategy docs live in a private repo.

## Status

- [x] Phase 1: research refresh
- [x] Phase 2: design system (docs/design-system.md) and clickable mockup (design/mockup/).
- [ ] Phase 3: Swift/SwiftUI app, version 1.0. In progress, see `tasks/todo.md` and `docs/PROGRESS.md`. Xcode 26.1.1, Firebase 12.x
- [ ] Phase 4: App Store icon, screenshots, listing
- [ ] Phase 5: landing page (slice-of-life.uk/invoice)
- [ ] Phase 6: launch video
- [ ] Phase 7: submit

[![CI](https://github.com/Gonzalo6282/InvoiceMaker/actions/workflows/ci.yml/badge.svg)](https://github.com/Gonzalo6282/InvoiceMaker/actions/workflows/ci.yml)

## Test the mockup

Double-click `design/mockup/index.html`. It opens in your browser and works offline.

Or serve it on localhost (needs Python):

```
cd design\mockup
python -m http.server 5173
```

Then open http://localhost:5173

Use the panel on the left to switch iPhone / iPad landscape / iPad portrait, light / dark, jump to any screen, and turn on test states (Premium, signed in, new user with no data, iCloud off, purchase fails, no connection). The panel also lists the Firebase events each action fires.

`mockup.artifact.html` is the same mockup without the HTML wrapper (used for the online link). After editing it, run `build.sh` to regenerate `index.html`.
