import SwiftUI

/// The navy "Owed to you" card (28pt radius). Lime only on money that arrived.
struct HeroCard: View {
    let owed: String
    let paidLabel: LocalizedStringKey
    let paid: String
    let overdue: String
    var hasOverdue = false
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Owed to you").font(.system(size: 13)).opacity(0.72)
                Text(owed).textStyle(.moneyDisplay).lineLimit(1).minimumScaleFactor(0.6)
            }
            Rectangle().fill(.white.opacity(0.14)).frame(height: 1)
            HStack(alignment: .top, spacing: 10) {
                figure(label: Text(paidLabel), value: paid, color: .paid)
                figure(label: Text("Overdue"), value: overdue, color: hasOverdue ? Color(red: 1, green: 0.56, blue: 0.64) : .white)
            }
            if let footnote {
                Text(footnote).font(.system(size: 12)).opacity(0.6)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.navy, in: RoundedRectangle(cornerRadius: 28))
        .accessibilityElement(children: .combine)
    }

    private func figure(label: Text, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label.font(.system(size: 13)).opacity(0.72)
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .tracking(-0.4)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
