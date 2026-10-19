import Foundation
import SwiftUI

/// Terms of Use and Privacy Policy, shown inside the app. The text lives in
/// Resources/Legal/*.txt (the same text is published on slice-of-life.uk).
nonisolated enum LegalDocument: String, Hashable, Sendable {
    case terms, privacy

    var title: String {
        switch self {
        case .terms: String(localized: "Terms of Use")
        case .privacy: String(localized: "Privacy Policy")
        }
    }

    /// The bundled text, split into blocks.
    var blocks: [LegalBlock] {
        let url = Bundle.main.url(forResource: rawValue, withExtension: "txt")
            ?? Bundle.main.url(forResource: rawValue, withExtension: "txt", subdirectory: "Legal")
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return LegalBlock.parse(text)
    }
}

/// "# Title", "## Heading", "### Subheading", "- bullet", plain paragraphs.
nonisolated enum LegalBlock: Hashable, Sendable {
    case title(String), heading(String), subheading(String), bullet(String), paragraph(String)

    static func parse(_ text: String) -> [LegalBlock] {
        text.components(separatedBy: .newlines).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { return nil }
            if line.hasPrefix("### ") { return .subheading(String(line.dropFirst(4))) }
            if line.hasPrefix("## ") { return .heading(String(line.dropFirst(3))) }
            if line.hasPrefix("# ") { return .title(String(line.dropFirst(2))) }
            if line.hasPrefix("- ") { return .bullet(String(line.dropFirst(2))) }
            return .paragraph(line)
        }
    }
}

struct LegalView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func view(for block: LegalBlock) -> some View {
        switch block {
        case .title:
            EmptyView()  // shown as the navigation title
        case .heading(let text):
            Text(verbatim: text).font(.headline).foregroundStyle(Color.ink).padding(.top, 12)
                .accessibilityAddTraits(.isHeader)
        case .subheading(let text):
            Text(verbatim: text).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink).padding(.top, 4)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "•").foregroundStyle(Color.ink2)
                Text(verbatim: text).foregroundStyle(Color.ink2)
            }
            .font(.subheadline)
        case .paragraph(let text):
            Text(verbatim: text).font(.subheadline).foregroundStyle(Color.ink2)
                .textSelection(.enabled)
        }
    }
}
