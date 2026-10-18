# Build plan: Duly (Invoice Maker) v1.0

Source: `SPEC.md` in the private docs repo (approved, all questions resolved), `docs/design-system.md`, `design/mockup/index.html`, Build Doc 1. Build order follows the spec's capability map. Every task ends with: tests green → `docs/PROGRESS.md` updated → commit + push to `main`.

## How the work runs

- **Where code is written:** a cloud clone of `github.com/Gonzalo6282/InvoiceMaker`. Each task is pushed to `main`; the Mac folder (`~/Desktop/InvoiceMaker`) gets it with **Source Control → Pull** in Xcode (or `git pull`).
- **Tests:** GitHub Actions (`.github/workflows/ci.yml`, macOS 26 runner, Xcode 26.1) runs `swift test` and `xcodebuild test` on iPhone and iPad simulators after every push; I read the result and fix failures before moving on. The repo is public so these minutes are free; strategy docs are in the private `InvoiceMaker-docs` repo.
- **On the Mac (✅ checkpoints):** signing, iCloud, real-device checks and looking at the UI.
- **Xcode project:** written by hand in Xcode 16+ format with **folder-synchronised groups**, so new Swift files appear in Xcode automatically and the project file almost never changes (fewer merge problems).

## Milestones

| # | Milestone | Modules | Checkpoint (you on the Mac) |
|---|---|---|---|
| M0 | Project skeleton | Xcode project, `Packages/InvoiceKit`, test targets, `.gitignore`, `PROGRESS.md` | Open project, set signing team, ⌘R shows blank app on iPhone 17 Pro sim |
| M1 | Money engine | `invoice-kit` (test-first, 100% coverage) | `swift test --package-path Packages/InvoiceKit` green |
| M2 | Foundation | `design-system`, `data-store` (CloudKit-safe SwiftData) | ⌘U green; design-system preview screen matches mockup |
| M3 | PDF | `pdf-render`: 7 templates, A4/Letter, QR, signatures, watermark, PAID stamp | Look at sample PDFs from the test bundle |
| M4 | Core app | `documents`, `clients-items` | Create → edit → preview an invoice end to end, no paywall yet |
| M5 | Settings + export | `settings`, `export` (ZIP + CSV) | Export a ZIP and CSV to Files |
| M6 | Services | `analytics`, `purchases`, `account` | Needs your keys (below); sandbox purchase works |
| M7 | Sending | `sending`: validation, Premium gate, share/Files/print, offline note | Send a PDF from the sim after sandbox purchase |
| M8 | Onboarding | `onboarding`: consent → welcome → role → business → first invoice → soft paywall | Fresh install walk-through |
| M9 | iPad + release checks | `ipad` pass, performance (1,000 invoices), bug checklist, UI tests | Real iPhone + iPad run of the bug checklist |

## Module notes (decisions taken from the spec, no new choices)

**invoice-kit (M1).** Pure Swift, Foundation only, Swift Testing. Types: `Decimal` rounding (**half-up to 2 dp**, per line then totals, matching the mockup's three cases £273.00 / £237.00 / £89.60), `Discount` (% or amount), `TaxRate` (name, %), `TaxMode` (.added/.included), `TaxPlacement` (.perItem/.onTotal), `Fee`, `LineItemInput`, `DocumentInput`, `Calculator.totals`, `TaxPresets` (UK, AU, CA incl. GST+PST/HST by province, US), `DocumentNumber` (prefix + zero-padded counter, INV/EST(QTE in UK)/RCT), `DocumentStatus` + overdue rule, `CurrencyDisplay` (symbol / code / none), `CSVWriter` (RFC 4180 escaping), `PaperSize.for(country:)`.

**design-system (M2).** Colour tokens as asset-catalog colours with dark variants (exact hex from design-system.md), `Typography` view modifiers, `PrimaryButton`/`GhostButton` (52pt capsules), `StatusPill`, `GroupedRow`, `HeroCard` (navy, 28pt), item icon tiles (pastel peach + orange tag; dark mode inverts). A debug-only gallery screen to compare with the mockup.

**data-store (M2).** `@Model` classes Business, Client, SavedItem, Document, LineItem, TaxRate, PaymentDetails; every property optional or defaulted, no `.unique`, all relationships optional (CloudKit rules). `ModelContainer` with `.private("iCloud.uk.slice-of-life.invoicemaker")`, in-memory variant for tests, `DemoData`. Mapping `Document → DocumentInput` so all maths goes through InvoiceKit. Schema versioned (`VersionedSchema` v1) from day one.

**pdf-render (M3).** `UIGraphicsPDFRenderer`; one `PDFTemplate` protocol, 7 implementations (Clean, Bold, Ledger free; Studio, Trades, Classic, Split Premium). Logo aspect-fit, brand colour, payment buttons as links + `CIQRCodeGenerator` QR, signature images with name + date, "Preview" watermark for non-Premium preview of Premium templates, PAID stamp. Snapshot tests render to PNG.

**documents / clients-items (M4).** Tabs: Invoices, Quotes/Estimates ("Quote" for UK storefront), Clients, Settings (match mockup). List with filters, search, month paid/owed hero card. Editor with autosave (SwiftData autosave + explicit save on background), line-item sheet, tax sheets, preview + template picker, more menu (duplicate, mark paid, make receipt, convert estimate, client signs, delete). PencilKit signature sheet. Contacts picker import. Saved items.

**settings / export (M5).** Every Settings row in the mockup. Export: render all PDFs into a temp folder, zip with `NSFileCoordinator(.forUploading)`; CSV via InvoiceKit. Free for everyone.

**analytics / purchases / account (M6).** One `AnalyticsEvent` enum with the Build Doc names; app version + country on every event; Consent Mode default denied for UK/EEA until the consent screen; no IDFA. RevenueCat 5.x (entitlement `pro`, AdServices token on), SuperwallKit 4.18.x with RevenueCat purchase controller, placements `onboarding_end`, `invoice_send`, `invoice_export_pdf`, `estimate_send`, `template_premium`, `settings_upgrade`; native fallback paywall; `InvoiceMaker.storekit` with the two 1.0 products (3-day trial on yearly). Sign in with Apple via Firebase Auth 12.x; Firebase UID → RevenueCat app user ID; Delete account. Services sit behind protocols so the app builds and runs with stubs until keys arrive.

**sending (M7).** Validate (client + ≥1 item) → Premium gate (Superwall) → optional sign-in at first send → share sheet / Files / print (anchored on iPad), offline note via `NWPathMonitor`, status → sent, `invoice_sent` / `pdf_exported`.

**onboarding (M8).** Consent (UK/EEA only, `Storefront.current?.countryCode`) → welcome → role → business → first invoice with live preview → soft paywall (`onboarding_end`).

**ipad (M9, and throughout).** `NavigationSplitView`; editor 440pt + live PDF in landscape; ⌘N/⌘S/⌘P; 560pt form sheets; 620pt paywall card; anchored popovers.

## Packages (all via SPM, none beyond the approved three)

| Package | Rule |
|---|---|
| firebase-ios-sdk | Up to Next Minor from **12.0.0**, latest 12.x (Xcode 26.1.1 can't build 13) — products FirebaseAuth, FirebaseAnalytics, FirebaseCrashlytics, FirebaseRemoteConfig |
| purchases-ios-spm | Up to Next Major from 5.0.0 — RevenueCat (+ RevenueCatUI not needed: paywalls are Superwall) |
| Superwall-iOS | Up to Next Minor from 4.18.0 — SuperwallKit |

Packages are added at M6, not M0, so the early milestones build fast and don't need keys.

## What I'll need from you, and when

| When | What |
|---|---|
| M0 | Open the project once, pick your signing team (Signing & Capabilities), add the iCloud container `iCloud.uk.slice-of-life.invoicemaker` if Xcode asks |
| M6 | Firebase `GoogleService-Info.plist` (drop in `InvoiceMaker/Resources/`, never committed), RevenueCat and Superwall API keys (go in untracked `Secrets.xcconfig`), App Store Connect products created |
| Each ✅ | Pull, run it, look at it |

## Risks

- **Compile errors** can't be caught in the cloud workspace itself. Mitigation: CI on every push; small tasks.
- **SwiftData + CloudKit** schema rules: enforced by a test that checks every model property is optional/defaulted.
- **Superwall paywall** depends on the web editor; the native fallback paywall keeps the send gate working regardless.
