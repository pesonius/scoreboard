import SwiftUI

struct SideStripView: View {
    let gamesHistory: [BadmintonState.GameRecord]
    let playerIndex: Int

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            ForEach(Array(gamesHistory.enumerated()), id: \.offset) { _, game in
                let mine = game.points[playerIndex]
                let opp  = game.points[1 - playerIndex]
                let won  = mine > opp
                Text("\(mine)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(won ? Color(hex: "#4cff4c") : Color(hex: "#888888"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
        }
        .background(Color(hex: "#0a0a0a"))
    }
}
