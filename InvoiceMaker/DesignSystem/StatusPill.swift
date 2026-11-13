import InvoiceKit
import SwiftUI

/// Status tag: Draft · Sent · Paid · Overdue · Accepted · Invoiced (SliceUI `Pill`).
struct StatusPill: View {
    let status: DisplayStatus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Pill(Text(title), tone: tone, accessibilityName: Text("Status"))
    }

    var title: LocalizedStringKey {
        switch status {
        case .draft: "Draft"
        case .sent: "Sent"
        case .paid: "Paid"
        case .overdue: "Overdue"
        case .accepted: "Accepted"
        case .converted: "Invoiced"
        }
    }

    private var tone: Pill.Tone {
        switch status {
        case .draft: .neutral
        case .sent: .accent
        case .paid: .success
        case .overdue: .danger
        case .accepted: .custom(foreground: colorScheme == .dark ? .paid : .paidInk, background: .paidWash, bordered: false)
        case .converted: .custom(foreground: .ink3, background: .canvas, bordered: true)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(DisplayStatus.allCases, id: \.self) { StatusPill(status: $0) }
    }
    .padding()
}
