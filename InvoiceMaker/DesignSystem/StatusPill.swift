import InvoiceKit
import SwiftUI

/// Status tag: Draft · Sent · Paid · Overdue · Accepted · Invoiced.
struct StatusPill: View {
    let status: DisplayStatus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .textStyle(.pill)
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(background, in: Capsule())
            .overlay {
                if hasBorder { Capsule().strokeBorder(Color.line, lineWidth: 1) }
            }
            .fixedSize()
            .accessibilityLabel(Text("Status: \(title)"))
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

    private var foreground: Color {
        switch status {
        case .draft: .ink2
        case .sent: .brand
        case .paid: .paidInk
        case .overdue: .due
        case .accepted: colorScheme == .dark ? .paid : .paidInk
        case .converted: .ink3
        }
    }

    private var background: Color {
        switch status {
        case .draft, .converted: .canvas
        case .sent: .brandWash
        case .paid: .paid
        case .overdue: .dueWash
        case .accepted: .paidWash
        }
    }

    private var hasBorder: Bool { status == .draft || status == .converted }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(DisplayStatus.allCases, id: \.self) { StatusPill(status: $0) }
    }
    .padding()
}
