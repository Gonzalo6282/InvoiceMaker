# German strings (switched off for v1.1)

v1.1 ships in English and French only (Build Doc, 27 Oct). The German app text
was taken out of `InvoiceMaker/Resources/Localizable.xcstrings` and kept here
(`Localizable.de.json`: key -> the catalog's `de` localization). To switch German
back on, merge each entry into `strings[key].localizations.de` and add `de` to
`knownRegions` in the project file.
