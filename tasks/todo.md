# To-do: Duly v1.0

One line = one task = one commit + push. Every push is tested by GitHub Actions (iPhone + iPad simulators). ✅ = checkpoint where you look at it on the Mac.

## M0 Project skeleton
- [x] T0.1 `tasks/plan.md`, `tasks/todo.md`, `docs/PROGRESS.md` (approved 18 Oct)
- [x] T0.2 Xcode project `InvoiceMaker.xcodeproj`: app target (iOS 17, universal, Swift 6 strict concurrency, bundle `uk.slice-of-life.invoicemaker`, display name "Duly"), unit + UI test targets, shared scheme, folder layout from SPEC, Assets, empty String Catalog, entitlements (iCloud/CloudKit, Sign in with Apple), `.gitignore` (Secrets.xcconfig, GoogleService-Info.plist, build/, DerivedData)
- [x] T0.3 `Packages/InvoiceKit` (Swift tools 6.0, Swift Testing) linked to the app
- [x] T0.4 Split repos (strategy docs → private `InvoiceMaker-docs`), make this repo public, GitHub Actions CI green
- [ ] ✅ You: open project, set signing team, ⌘R on iPhone sim

## M1 invoice-kit (test-first)
- [x] T1.1 Rounding + `Discount` (% / amount) + `LineItemInput.net`
- [x] T1.2 `TaxRate`, tax added vs included, per item vs on total, several named taxes
- [x] T1.3 `Calculator.totals` with shipping + fees; the mockup's 3 cases (£273.00, £237.00, CA GST+PST £89.60)
- [x] T1.4 `TaxPresets` UK / AU / CA (by province) / US
- [x] T1.5 `DocumentNumbering` (INV- / EST- / REC-, padding, next number; "Quote" title in the UK)
- [x] T1.6 `DocumentStatus` + overdue rule + month paid/owed totals
- [x] T1.7 `CurrencyDisplay` (symbol / code / none) + `PaperSize.for(country:)`
- [x] T1.8 `CSVWriter` with escaping
- [x] ✅ `swift test --package-path Packages/InvoiceKit` green, 100% coverage (CI enforces 100%)

## M2 design-system + data-store
- [x] T2.1 Colour tokens (asset catalog, light/dark) + typography modifiers
- [x] T2.2 Buttons, pills, rows, hero card, icon tiles + debug gallery screen
- [x] T2.3 SwiftData models v1 (CloudKit-safe) + `ModelContainer` (CloudKit / in-memory)
- [x] T2.4 `Document → DocumentInput` mapping, demo data, CloudKit-safety test, CRUD integration tests
- [x] ✅ Tests green on CI (iPhone + iPad) · [ ] you: look at the Design system gallery vs the mockup

## M3 pdf-render
- [x] T3.1 Renderer core: paper size, layout helpers, logo fit, QR, payment buttons, signatures
- [x] T3.2 Free templates: Clean, Bold, Ledger
- [x] T3.3 Premium templates: Studio, Trades, Classic, Split; Preview watermark; PAID stamp
- [x] T3.4 Snapshot tests (7 × invoice/quote/receipt × A4/Letter), HEIC logo
- [x] ✅ Sample PDFs reviewed from CI snapshots (fixed pay-button wrap, empty payment block, stamp blend)

## M4 documents + clients-items
- [x] T4.1 App shell: tabs (iPhone) / split view (iPad), router, AppState
- [x] T4.2 Documents list: filters, search, month totals hero card, empty state
- [x] T4.3 Editor: client, dates, number, notes, autosave
- [x] T4.4 Line-item sheet + saved items + tax/discount/fees sheets
- [x] T4.5 Preview + template picker (Premium templates marked)
- [x] T4.6 More menu: duplicate, mark paid, make receipt, convert estimate, delete
- [x] T4.7 Signatures: draw mine (PencilKit), client signs quote/invoice
- [x] T4.8 Clients: list, detail, Contacts import, currency per client; saved items list
- [x] ✅ Create → add item → total, on CI (iPhone + iPad) · [ ] you: try it on the Mac

## M5 settings + export
- [x] T5.1 Settings: business profile (PhotosPicker logo), taxes, payment details, invoice look, signature, numbering/defaults, currency display
- [x] T5.2 Settings: backup status (iCloud on/off), help, report a problem, legal links
- [x] T5.3 Export: PDFs as ZIP, data as CSV (free)
- [x] ✅ Export ZIP + CSV tested on CI · [ ] you: export to Files on the Mac/device

## M6 analytics + purchases + account  (needs your keys)
- [ ] T6.1 Add Firebase 12.x, RevenueCat 5.x, SuperwallKit 4.18.x packages; `Secrets.xcconfig` template
- [ ] T6.2 Analytics: `AnalyticsEvent`, consent screen (UK/EEA), Consent Mode, Crashlytics, Remote Config defaults
- [ ] T6.3 Purchases: RevenueCat setup, `pro` entitlement state, StoreKit config file, restore, manage subscription
- [ ] T6.4 Superwall placements + RevenueCat purchase controller + native fallback paywall
- [ ] T6.5 Account: Sign in with Apple via Firebase, UID → RevenueCat, delete account
- [ ] ✅ Sandbox purchase unlocks `pro`

## M7 sending
- [ ] T7.1 Validation + Premium gate + sign-in offer at first send
- [ ] T7.2 Share sheet / Files / print (anchored on iPad), offline note, status → sent, events
- [ ] ✅ Send after sandbox purchase

## M8 onboarding
- [ ] T8.1 Consent → welcome → role → business → first invoice (live preview) → soft paywall
- [ ] ✅ Fresh-install walk-through

## M9 iPad + release checks
- [ ] T9.1 iPad pass: editor + live PDF, ⌘N/⌘S/⌘P, form sheets, popovers, Split View, Stage Manager
- [ ] T9.2 Performance: 1,000 invoices, open < 0.5 s
- [ ] T9.3 UI tests: onboarding, create → send gate → purchase → share, iPad landscape
- [ ] T9.4 Largest Dynamic Type + accessibility labels
- [ ] ✅ Bug checklist on real iPhone + iPad

## Later (from HANDOFF)
- [ ] "Continue the build" skill + scheduled task to resume after usage-limit resets
