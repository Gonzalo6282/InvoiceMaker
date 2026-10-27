import InvoiceKit
import SwiftUI

struct EditorDetailsSection: View {
    @Bindable var document: Document
    let business: Business
    @Environment(\.modelContext) private var context

    var body: some View {
        GroupedSection(header: "Details") {
            FieldRow(label: "Number") {
                TextField("Number", text: $document.number)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
            RowDivider()
            if document.kind == .receipt {
                FieldRow(label: "Paid on") {
                    DatePicker("Paid on", selection: paidOn, displayedComponents: .date).labelsHidden()
                }
            } else {
                FieldRow(label: "Issued") {
                    DatePicker("Issued", selection: $document.issueDate, displayedComponents: .date).labelsHidden()
                }
                RowDivider()
                FieldRow(label: document.kind == .estimate ? "Valid until" : "Due") {
                    DatePicker("Due", selection: dueDate, in: document.issueDate..., displayedComponents: .date).labelsHidden()
                }
            }
            RowDivider()
            FieldRow(label: "Job or site") {
                TextField("Optional", text: $document.job)
            }
            if document.kind == .invoice {
                RowDivider()
                FieldRow(label: "Repeat") { repeatMenu }
                if let source = document.recurringFromNumber {
                    RowDivider()
                    FieldRow(label: "Repeat of") { Text(verbatim: source).foregroundStyle(Color.ink2) }
                }
            }
        }
        .onChange(of: document.number) { document.updatedAt = .now }
        .onChange(of: document.job) { document.updatedAt = .now }
        .onChange(of: document.issueDate) {
            // The schedule counts from the invoice date.
            if let recurrence = document.recurrence { RecurringInvoices(context: context).set(recurrence, on: document) }
        }
    }

    private var repeatMenu: some View {
        Menu {
            Button("Never") { RecurringInvoices(context: context).set(nil, on: document); reschedule() }
            ForEach(Recurrence.allCases, id: \.self) { recurrence in
                Button(recurrence.title) { choose(recurrence) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(RecurringInvoices.summary(document, business: business) ?? String(localized: "Never"))
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .foregroundStyle(document.recurrence == nil ? Color.ink2 : Color.brand)
        }
        .accessibilityIdentifier("repeatMenu")
    }

    /// Premium; asks for notification permission so the "ready to send" note can arrive.
    private func choose(_ recurrence: Recurrence) {
        PaywallService.shared.gate(.recurringInvoice) {
            RecurringInvoices(context: context).set(recurrence, on: document)
            AppAnalytics.shared.log(.recurringSet, ["frequency": recurrence.rawValue])
            Task {
                _ = await Reminders.requestPermission()
                reschedule()
            }
        }
    }

    private func reschedule() {
        Reminders.reschedule(context: context, business: business)
    }

    private var paidOn: Binding<Date> {
        Binding(get: { document.paidOn ?? document.issueDate }, set: { document.paidOn = $0; document.updatedAt = .now })
    }

    private var dueDate: Binding<Date> {
        Binding(
            get: { document.dueDate ?? document.issueDate },
            set: { document.dueDate = $0; document.updatedAt = .now })
    }
}
