import InvoiceKit
import SwiftUI

struct EditorDetailsSection: View {
    @Bindable var document: Document
    let business: Business

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
        }
        .onChange(of: document.number) { document.updatedAt = .now }
        .onChange(of: document.job) { document.updatedAt = .now }
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
