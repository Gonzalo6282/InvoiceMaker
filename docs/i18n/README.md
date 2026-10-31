# Translations

The app ships in English (UK source, with a US English variant), French,
German and Spanish. All app text is in `InvoiceMaker/Resources/Localizable.xcstrings`.

- v1.1: English and French. German was switched off.
- v1.2: German back on; Spanish added (Latin American, "tú" like iOS in Mexico,
  "cotización" for estimates). Mexico is a region (MXN, IVA 16/8/0 %, RFC,
  CLABE, US Letter). Duly makes PDF invoices, not CFDI; the app and the Terms say so.
- Terms and Privacy: `Resources/Legal/*.fr.txt`, `*.de.txt`, `*.es.txt` (formal
  register). The English versions are binding; each translation says so at the top.
- Test `translationsShipInTheApp` checks each language is in the build.
