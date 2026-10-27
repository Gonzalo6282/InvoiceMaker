import InvoiceKit
import PhotosUI
import SwiftData
import SwiftUI

/// Name, logo, contact details, country, tax registration, defaults.
struct BusinessProfileView: View {
    @Bindable var business: Business
    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LogoPickerRow(business: business).padding(.horizontal, 16).padding(.top, 6)
                GroupedSection(header: "Business") {
                    FieldRow(label: "Name") { TextField("Business name", text: $business.name) }
                    RowDivider()
                    FieldRow(label: "Email") {
                        TextField("you@business.com", text: $business.email)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    RowDivider()
                    FieldRow(label: "Phone") { TextField("Optional", text: $business.phone).keyboardType(.phonePad) }
                    RowDivider()
                    AddressField(text: $business.address, homeCountry: business.countryCode)
                }
                GroupedSection(header: "Country and tax", footer: LocalizedStringKey(note)) {
                    FieldRow(label: "Country") {
                        Picker("Country", selection: country) {
                            ForEach(Region.allCases, id: \.self) { Text($0.countryName).tag($0) }
                        }
                        .labelsHidden()
                    }
                    RowDivider()
                    Toggle(registeredLabel, isOn: $business.taxRegistered).padding(.horizontal, 14).frame(minHeight: 48)
                    if business.taxRegistered {
                        RowDivider()
                        FieldRow(label: LocalizedStringKey(business.region.preset.taxIDLabel)) { TextField("Optional", text: $business.taxID) }
                    }
                    RowDivider()
                    FieldRow(label: "Default currency") {
                        Picker("Default currency", selection: $business.currencyCode) {
                            ForEach(currencies, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                    RowDivider()
                    FieldRow(label: "Default tax") {
                        Picker("Default tax", selection: $business.defaultTaxID) {
                            Text("None").tag(String?.none)
                            ForEach(taxRecords.filter { !$0.isArchived }) { Text($0.taxRate.label).tag(Optional($0.taxID)) }
                        }
                        .labelsHidden()
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle("Business profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var country: Binding<Region> {
        Binding(
            get: { business.region },
            set: { region in
                business.countryCode = region.isoCode
                business.currencyCode = region.preset.currencyCode
            })
    }

    private var registeredLabel: LocalizedStringKey {
        switch business.region {
        case .us: "I collect sales tax"
        case .uk: "VAT registered"
        case .au, .ca: "GST registered"
        }
    }

    private var note: String {
        switch business.region {
        case .uk: String(localized: "Only VAT-registered businesses add VAT and show a VAT number.")
        case .au: String(localized: "GST-registered businesses title the document \"Tax invoice\" and show their ABN.")
        case .ca: String(localized: "Rates depend on the province. You can add two taxes to one invoice (GST plus PST or QST).")
        case .us: String(localized: "US sales tax depends on state, county and city. Type your rate once and it is saved.")
        }
    }

    private var currencies: [String] {
        let base = ["GBP", "EUR", "USD", "AUD", "CAD", "NZD"]
        return base.contains(business.currencyCode) ? base : [business.currencyCode] + base
    }
}

extension Region {
    var isoCode: String {
        switch self {
        case .uk: "GB"
        case .au: "AU"
        case .ca: "CA"
        case .us: "US"
        }
    }

    var countryName: String {
        Locale.current.localizedString(forRegionCode: isoCode) ?? isoCode
    }
}

/// "Add your logo" from Photos. Stored downscaled; shown whole, never cropped.
struct LogoPickerRow: View {
    @Bindable var business: Business
    @State private var item: PhotosPickerItem?

    var body: some View {
        Group {
            HStack(spacing: 14) {
                Group {
                    if let data = business.logoData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit().padding(4).background(.white)
                    } else {
                        Image(systemName: "photo").font(.title2).foregroundStyle(Color.brand)
                    }
                }
                .frame(width: 64, height: 64)
                .background(Color.brandWash, in: RoundedRectangle(cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(business.logoData == nil ? "Add your logo" : "Change logo").font(.callout.weight(.semibold)).foregroundStyle(Color.ink)
                    Text("From Photos. JPEG, PNG or HEIC. Shown whole, never cropped.").font(.footnote).foregroundStyle(Color.ink2)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        }
        .logoPhotoPicker(selection: $item)
        .contextMenu {
            if business.logoData != nil {
                Button("Remove logo", systemImage: "trash", role: .destructive) { business.logoData = nil }
            }
        }
        .onChange(of: item) {
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    business.logoData = LogoImage.prepare(data)
                }
                self.item = nil
            }
        }
    }
}

enum LogoImage {
    /// Downscales to at most 1024 px on the long side and stores PNG (keeps transparency).
    static func prepare(_ data: Data, maxSide: CGFloat = 1024) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.pngData()
    }
}
