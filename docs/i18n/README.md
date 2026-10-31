# Translations

The app ships in English (UK source, with a US English variant), French,
German and Spanish. All app text is in `InvoiceMaker/Resources/Localizable.xcstrings`.

- v1.1: English and French. German was switched off.
- v1.2: German back on; Spanish added (Latin American, "tú" like iOS in Mexico,
  "cotización" for estimates). Mexico is a region (MXN, IVA 16/8/0 %, RFC,
  CLABE, US Letter). Duly makes PDF invoices, not CFDI; the app and the Terms say so.
- Spain: `es-ES` is a full copy of `es` with Spain's words (presupuesto, Ajustes,
  añadir, importe, informes, copia de seguridad...). It must stay complete: iOS
  falls back from es-ES to English, not to `es` (the test checks 400+ strings).
  Spain is a region (EUR, IVA 21/10/4/0 %, NIF, IBAN).
- Terms and Privacy: `Resources/Legal/*.fr.txt`, `*.de.txt`, `*.es.txt` (formal
  register). The English versions are binding; each translation says so at the top.
- Test `translationsShipInTheApp` checks each language is in the build.
