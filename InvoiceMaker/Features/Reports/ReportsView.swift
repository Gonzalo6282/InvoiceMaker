import Charts
import InvoiceKit
import SwiftData
import SwiftUI

/// Reports (v1.1, Premium): what was invoiced and paid by month and by client,
/// for one year and one currency, with CSV export.
struct ReportsView: View {
    let business: Business
    @Environment(\.modelContext) private var context
    @Query private var documents: [Document]
    @State private var purchases = PurchaseManager.shared
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var currency: String?
    @State private var file: SharedFile?
    @State private var exportFailed = false

    var body: some View {
        ScrollView {
            if purchases.isPremium {
                content
            } else {
                locked
            }
        }
        .background(Color.canvas)
        .navigationTitle("Reports")
        .toolbar {
            if purchases.isPremium, !inputs.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Export CSV", systemImage: "square.and.arrow.up", action: export)
                        .accessibilityIdentifier("exportReport")
                }
            }
        }
        .sheet(item: $file) { file in ShareSheet(items: [file.url]).ignoresSafeArea() }
        .alert("Export didn't work", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        }
        .onAppear { AppAnalytics.shared.log(.reportsViewed, ["premium": purchases.isPremium ? "true" : "false"]) }
    }

    // MARK: Data

    private var inputs: [ReportInput] {
        let taxes = (try? BusinessSetup.taxes(in: context, includingArchived: true)) ?? []
        return documents.filter { $0.kind == .invoice && $0.status != .draft }.map {
            ReportInput(
                kind: $0.kind, status: $0.status, issueDate: $0.issueDate, due: $0.dueDate, paidOn: $0.paidOn,
                currencyCode: $0.currencyCode, total: $0.totals(taxes: taxes).total, clientName: $0.client?.name ?? "")
        }
    }

    private func report(_ inputs: [ReportInput]) -> Report {
        Report(documents: inputs, year: year, currencyCode: currency ?? business.currencyCode)
    }

    private func monthName(_ month: Int) -> String {
        var calendar = Calendar.current
        calendar.locale = business.locale
        return calendar.shortMonthSymbols[month - 1]
    }

    private func money(_ amount: Decimal, _ report: Report) -> String {
        business.money(amount, currency: report.currencyCode)
    }

    // MARK: Views

    @ViewBuilder private var content: some View {
        let inputs = self.inputs
        if inputs.isEmpty {
            ContentUnavailableView(
                "No sent invoices yet", systemImage: "chart.bar",
                description: Text("Your totals by month and by client appear here once you send invoices."))
                .padding(.top, 60)
        } else {
            let report = report(inputs)
            VStack(alignment: .leading, spacing: 0) {
                pickers(inputs)
                summary(report)
                chart(report)
                GroupedSection(header: "By client") {
                    if report.clients.isEmpty {
                        Row(verbatim: String(localized: "No invoices in \(String(year))"))
                    }
                    ForEach(Array(report.clients.enumerated()), id: \.offset) { index, client in
                        if index > 0 { RowDivider() }
                        Row(
                            verbatim: client.name,
                            meta: client.unpaid > 0
                                ? String(localized: "\(client.invoices) invoices · \(money(client.unpaid, report)) unpaid")
                                : String(localized: "\(client.invoices) invoices · all paid"),
                            value: money(client.invoiced, report))
                    }
                }
                GroupedSection(header: "By month", footer: "Invoiced by invoice date, paid by the date the money arrived.") {
                    let active = report.months.filter { $0.invoiced != 0 || $0.paid != 0 }
                    if active.isEmpty { Row(verbatim: String(localized: "No invoices in \(String(year))")) }
                    ForEach(Array(active.enumerated()), id: \.element.month) { index, month in
                        if index > 0 { RowDivider() }
                        Row(
                            verbatim: monthName(month.month),
                            meta: String(localized: "Paid \(money(month.paid, report))"),
                            value: money(month.invoiced, report))
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func pickers(_ inputs: [ReportInput]) -> some View {
        let years = Set(Report.years(in: inputs) + [year]).sorted(by: >)
        let currencies = Report.currencies(in: inputs, preferred: business.currencyCode)
        return HStack(spacing: 10) {
            Picker("Year", selection: $year) {
                ForEach(years, id: \.self) { Text(verbatim: String($0)).tag($0) }
            }
            .pickerStyle(.menu)
            if currencies.count > 1 {
                Picker("Currency", selection: Binding(get: { currency ?? business.currencyCode }, set: { currency = $0 })) {
                    ForEach(currencies, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func summary(_ report: Report) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Invoiced in \(String(report.year))").font(.footnote).opacity(0.72)
                Text(money(report.invoiced, report)).textStyle(.moneyDisplay).lineLimit(1).minimumScaleFactor(0.6)
            }
            Rectangle().fill(.white.opacity(0.14)).frame(height: 1)
            HStack(alignment: .top, spacing: 10) {
                figure("Paid", money(report.paid, report), color: .paid)
                figure("Unpaid", money(report.unpaid, report), color: .white)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.navy, in: RoundedRectangle(cornerRadius: 28))
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func figure(_ label: LocalizedStringKey, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.footnote).opacity(0.72)
            Text(value).font(.title3.weight(.heavy)).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chart(_ report: Report) -> some View {
        let invoiced = String(localized: "Invoiced")
        let paid = String(localized: "Paid")
        return Chart {
            ForEach(report.months, id: \.month) { month in
                BarMark(x: .value("Month", monthName(month.month)), y: .value("Amount", NSDecimalNumber(decimal: month.invoiced).doubleValue))
                    .foregroundStyle(by: .value("Series", invoiced))
                    .position(by: .value("Series", invoiced))
                BarMark(x: .value("Month", monthName(month.month)), y: .value("Amount", NSDecimalNumber(decimal: month.paid).doubleValue))
                    .foregroundStyle(by: .value("Series", paid))
                    .position(by: .value("Series", paid))
            }
        }
        .chartForegroundStyleScale([invoiced: Color.brand, paid: Color.paid])
        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.caption2) } }
        .frame(height: 180)
        .padding(14)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .accessibilityLabel(Text("Invoiced and paid by month"))
    }

    private var locked: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 44)).foregroundStyle(Color.brand)
            Text("See what you earn").textStyle(.total).multilineTextAlignment(.center)
            Text("Totals by month and by client, what's still unpaid, and a CSV for your accountant.")
                .font(.subheadline).foregroundStyle(Color.ink2).multilineTextAlignment(.center)
            Button("Unlock reports") { PaywallService.shared.gate(.reports) {} }
                .buttonStyle(.primary)
                .accessibilityIdentifier("unlockReports")
        }
        .padding(28)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: Export

    private func export() {
        let report = report(inputs)
        let name = String(localized: "Duly report \(String(report.year)) \(report.currencyCode)") + ".csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try report.csv(monthName: monthName).write(to: url, atomically: true, encoding: .utf8)
            file = SharedFile(url: url)
            AppAnalytics.shared.log(.reportExported)
        } catch {
            exportFailed = true
        }
    }
}
