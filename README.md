# Invoice Maker (Slice of Life Ltd)

App 1 of 6 in Plan C. Built phase by phase from *Build Doc 1: Invoice Maker*.

## Status

- [x] Phase 1: research refresh (docs/phase1-research.md)
- [x] Phase 2: design system (docs/design-system.md) and clickable mockup (design/mockup/). **Waiting for your approval.**
- [ ] Phase 3: Swift/SwiftUI app, version 1.0. Spec drafted (docs/SPEC.md), waiting for approval. Code is written on the Mac (Xcode 26.1.1, Firebase 12.x)
- [ ] Phase 4: App Store icon, screenshots, listing
- [ ] Phase 5: landing page (slice-of-life.uk/invoice)
- [ ] Phase 6: launch video
- [ ] Phase 7: submit

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
