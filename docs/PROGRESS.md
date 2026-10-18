# Progress

Updated after every task. Plan: `tasks/plan.md`. Task list: `tasks/todo.md`.

| Date | Task | Result |
|---|---|---|
| 18 Oct 2026 | T0.1 Plan and task list | Approved by Gonzalo |
| 18 Oct 2026 | T0.3 `Packages/InvoiceKit` | Swift tools 6.0, iOS 17 / macOS 14, Swift Testing; placeholder `InvoiceKit.version` + 1 test |
| 18 Oct 2026 | T0.2 Xcode project | `InvoiceMaker.xcodeproj` (Xcode 16+ format, folder-synchronised groups): app + unit + UI test targets, shared scheme (also runs InvoiceKitTests), iOS 17, iPhone + iPad, Swift 6, main-actor default isolation, bundle `uk.slice-of-life.invoicemaker`, home-screen name "Duly", entitlements for CloudKit (`iCloud.uk.slice-of-life.invoicemaker`), push (CloudKit sync) and Sign in with Apple. Not yet built on the Mac |
| 18 Oct 2026 | T0.4 Repo split + CI | Spec, handoff and research moved to private `Gonzalo6282/InvoiceMaker-docs` and removed from this repo's history; `.github/workflows/ci.yml` (macOS 26, Xcode 26.1, `swift test` + `xcodebuild test` on iPhone 17 Pro and iPad Air 11-inch M3) |
| 18 Oct 2026 | CI fixes | GitHub's Macs have Xcode 26.1.1 but only iOS 26.2+ simulators, so CI has two jobs: **compile** with Xcode 26.1.1 (downloads its iOS platform) and **test** on the newest Xcode (26.6) with iPhone 17 Pro + iPad Air 11-inch (M3) simulators. Errors show as annotations (raw logs aren't reachable from the cloud workspace) |
| 18 Oct 2026 | T1.1–T1.8 InvoiceKit | Rounding (half-up), discounts, line nets, named taxes (added/included, per item/on total), `Calculator.totals` (ports the mockup's `calc()`), region presets UK/AU/CA/US + titles ("Quote" UK, "Tax invoice" AU) + paper size, numbering INV-/EST-/REC-, status/overdue + owed/paid-this-month summary, currency display, CSV with formula-injection guard. 60+ tests green on CI; tests caught a real CSV line-break bug. Coverage now enforced at 100% |

## Current state
- Waiting for: Gonzalo to make this repo public (so CI minutes are free), reset the Mac copy, set the signing team (checkpoint M0).
- Next: M2 design-system (T2.1 colour tokens + type styles in progress), then data-store.
- How work flows: code is written in a cloud clone and pushed to `main`; GitHub Actions runs every test; the Mac pulls.
- Spec and strategy: private repo `Gonzalo6282/InvoiceMaker-docs` (`HANDOFF.md`, `SPEC.md`). Never copy pricing or keywords into this public repo.
