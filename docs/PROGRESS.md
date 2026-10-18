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
| 18 Oct 2026 | T2.1 Colour tokens + type | 24 colour sets (light/dark, from design-system.md and the mockup CSS, incl. item tile/glyph and chip colours) used as `Color.ink`, `Color.brand`…; `textStyle(_:)` modifier with Dynamic Type scaling and tabular digits. Coverage 100% (329 lines) |
| 18 Oct 2026 | T2.2 Components | Primary/ghost/small capsule buttons, status pills, grouped sections + rows + hairlines, icon chips, avatar initials, navy hero card; debug-only Design system gallery (Root → "Design system") |
| 18 Oct 2026 | T2.3 SwiftData schema v1 | Business, PaymentDetails, TaxRateRecord, Client, SavedItem, Document, LineItem in `SchemaV1` + migration plan. CloudKit rules checked by tests (defaults, no unique, optional relationships with inverses). Models are `nonisolated` (the target's main-actor default makes SwiftData trap otherwise). Store: CloudKit → local fallback → error screen, in-memory under tests |
| 18 Oct 2026 | T2.4 Document actions | Create (numbering, client currency, defaults), duplicate, receipt from invoice, estimate → invoice, mark sent/paid/unpaid, client signature, add/delete/reorder lines, delete; Document → InvoiceKit mapping; demo data (Kestrel Joinery). 20 integration tests incl. "delete a line item and reopen". Lesson: keep a `ModelContainer` alive while using its context (SwiftData traps otherwise) |
| 18 Oct 2026 | CI diagnostics | Full logs, xcresult summaries and crash reports are pushed to the `ci-logs` branch; PDF snapshot PNGs to `ci-snapshots` |

## Current state
- Waiting for: Gonzalo to make this repo public (so CI minutes are free), reset the Mac copy, set the signing team (checkpoint M0).
- Next: M3 PDF templates (T3.1–T3.4).
- How work flows: code is written in a cloud clone and pushed to `main`; GitHub Actions runs every test; the Mac pulls.
- Spec and strategy: private repo `Gonzalo6282/InvoiceMaker-docs` (`HANDOFF.md`, `SPEC.md`). Never copy pricing or keywords into this public repo.
