# Progress

Updated after every task. Plan: `tasks/plan.md`. Task list: `tasks/todo.md`.

| Date | Task | Result |
|---|---|---|
| 18 Oct 2026 | T0.1 Plan and task list | Approved by Gonzalo |
| 18 Oct 2026 | T0.3 `Packages/InvoiceKit` | Swift tools 6.0, iOS 17 / macOS 14, Swift Testing; placeholder `InvoiceKit.version` + 1 test |
| 18 Oct 2026 | T0.2 Xcode project | `InvoiceMaker.xcodeproj` (Xcode 16+ format, folder-synchronised groups): app + unit + UI test targets, shared scheme (also runs InvoiceKitTests), iOS 17, iPhone + iPad, Swift 6, main-actor default isolation, bundle `uk.slice-of-life.invoicemaker`, home-screen name "Duly", entitlements for CloudKit (`iCloud.uk.slice-of-life.invoicemaker`), push (CloudKit sync) and Sign in with Apple. Not yet built on the Mac |

## Current state
- Waiting for: Gonzalo to pull, open the project, set the signing team, ⌘R and ⌘U (checkpoint M0).
- Next: M1 invoice-kit, T1.1 rounding + discounts (test-first).
- How work flows: code is written in a cloud clone and pushed to `main`; the Mac pulls. Tests run on the Mac.
