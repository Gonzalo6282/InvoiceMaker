# To-do: Duly v1.0

One line = one task = one commit + push. Every push is tested by GitHub Actions (iPhone + iPad simulators). ✅ = checkpoint where you look at it on the Mac.

## M0 Project skeleton
- [x] T0.1 `tasks/plan.md`, `tasks/todo.md`, `docs/PROGRESS.md` (approved 18 Oct)
- [x] T0.2 Xcode project `InvoiceMaker.xcodeproj`: app target (iOS 17, universal, Swift 6 strict concurrency, bundle `uk.slice-of-life.invoicemaker`, display name "Duly"), unit + UI test targets, shared scheme, folder layout from SPEC, Assets, empty String Catalog, entitlements (iCloud/CloudKit, Sign in with Apple), `.gitignore` (Secrets.xcconfig, GoogleService-Info.plist, build/, DerivedData)
- [x] T0.3 `Packages/InvoiceKit` (Swift tools 6.0, Swift Testing) linked to the app
- [x] T0.4 Split repos (strategy docs → private `InvoiceMaker-docs`), make this repo public, GitHub Actions CI green
- [x] ✅ You: open project, set signing team, ⌘R on iPhone sim

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
- [x] ✅ Tests green on CI (iPhone + iPad) · [x] you: look at the Design system gallery vs the mockup

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
- [x] ✅ Create → add item → total, on CI (iPhone + iPad) · [x] you: try it on the Mac

## M5 settings + export
- [x] T5.1 Settings: business profile (PhotosPicker logo), taxes, payment details, invoice look, signature, numbering/defaults, currency display
- [x] T5.2 Settings: backup status (iCloud on/off), help, report a problem, legal links
- [x] T5.3 Export: PDFs as ZIP, data as CSV (free)
- [x] ✅ Export ZIP + CSV tested on CI · [x] you: export to Files on the Mac/device

## M6 analytics + purchases + account  (needs your keys)
- [x] T6.1 Add Firebase 12.x, RevenueCat 5.x, SuperwallKit 4.18.x packages; `Secrets.xcconfig` template
- [x] T6.2 Analytics: `AnalyticsEvent`, consent screen (UK/EEA), Consent Mode, Crashlytics, Remote Config defaults
- [x] T6.3 Purchases: RevenueCat setup, `pro` entitlement state, StoreKit config file, restore, manage subscription
- [x] T6.4 Superwall placements + RevenueCat purchase controller + native fallback paywall
- [x] T6.5 Account: Sign in with Apple via Firebase, UID → RevenueCat, delete account
- [x] ✅ You: sandbox/StoreKit-file purchase unlocks `pro` (keys are in your local Secrets.xcconfig)

## M7 sending
- [x] T7.1 Validation + Premium gate + sign-in offer at first send
- [x] T7.2 Share sheet / Files / print (anchored on iPad), offline note, status → sent, events
- [x] ✅ You: send after a test purchase

## M8 onboarding
- [x] T8.1 Consent → welcome → role → business → first invoice (live preview) → soft paywall
- [x] ✅ Onboarding UI test on CI · [x] you: fresh-install walk-through on the Mac

## M9 iPad + release checks
- [x] T9.1 iPad pass: editor + live PDF, ⌘N/⌘S/⌘P, form sheets, popovers, Split View, Stage Manager
- [x] T9.2 Performance: 1,000 invoices, open < 0.5 s
- [x] T9.3 UI tests: onboarding, create → send gate → purchase → share, iPad landscape
- [x] T9.4 Largest Dynamic Type + accessibility labels
- [x] ✅ Bug checklist on real iPhone + iPad

## v1.0.1 (after App Review approves 1.0, before v2)
- [ ] Paywall yearly card (Superwall "Duly Premium"): 1.0 shows **$99.99/year** bold on the right and "Only $8.33/month" under "Yearly" (24 Oct, for review: Apple 3.1.2 wants the billed amount to be the most prominent price). Gonzalo wants to try the monthly breakdown in the main price spot again. Before changing: re-check Apple's current 3.1.2 wording; consider testing it as a Superwall A/B rather than a switch for everyone
- [ ] Screen 2 of the App Store screenshots: replace the small preview photo with the licensed full-size original (iPhone + iPad)

- [ ] UK App Store set: screenshots with the UK demo (£, "Quotes") and an en-GB listing
- [ ] US English in the app for US users ("Color", not "Colour"): add an en-US string variant or neutral wording
- [ ] Delete account: when Apple's sign-in returns error 1000 / AKAuthenticationError -7071, explain the fix (Settings > [name] > Sign-In & Security > Sign in with Apple > Duly > Stop Using) instead of the raw error
- [ ] Launch log "default Firebase app has not yet been configured": find what touches Firebase before `configure()` and move it after
- [ ] Rating badge on screenshot 1 once the app has ratings
- [ ] After ~30 days: check keyword results (swap "handyman" for "payment,tracker" if weak) and the paywall numbers (trial and pay rates)
- [ ] Superwall test: $9.99 save offer when someone closes the paywall or taps Manage subscription

## v1.1 (Build Doc)
- [ ] Recurring invoices (weekly, monthly, yearly; app prepares the next one and reminds the user)
- [ ] Due-date reminders to the user (local notifications)
- [ ] Job photos on invoices
- [ ] Reports: totals by client and by month, CSV export
- [ ] Client address autocomplete (Apple Maps)
- [ ] German and French templates and listings

## v1.2 (Build Doc: payments)
- [ ] Connect Stripe in Settings; "Pay now" button and hosted link for the exact amount (card, Apple Pay, Google Pay, US bank); 1% application fee
- [ ] Invoices marked paid automatically (Stripe webhook + push)
- [ ] Pass the processing fee on (US); partial payments and deposits
- [ ] Automatic reminder emails to clients
- [ ] Server: Firebase Cloud Functions + Firestore (Stripe secret key on the server only)

## Later versions (Build Doc)
- [ ] Tap to Pay on iPhone · receipt and expense scanning · projects · Japanese and Spanish

## Later (from HANDOFF)
- [ ] "Continue the build" skill + scheduled task to resume after usage-limit resets
