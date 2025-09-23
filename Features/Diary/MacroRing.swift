// Features/Diary/MacroRing.swift
import SwiftUI

struct MacroRing: View {
    let g: DiaryViewModel.MacroGoal

    private var col: Color {
        switch g.kind {
        case .carbs: return .teal
        case .fat: return .purple
        case .protein: return .orange
        }
    }

    private var title: String {
        switch g.kind {
        case .carbs: "Carbs"
        case .fat: "Fat"
        case .protein: "Protein"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(col)

            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.15), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: g.progress)
                    .stroke(
                        col,
                        style: .init(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: g.progress)

                VStack(spacing: 0) {
                    Text(Int(g.eaten).formatted())
                        .font(.title3)
                        .bold()
                    Text("/\(Int(g.target))g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            Text("\(Int(g.remaining))g left")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
//
//  MacroRing.swift
//  CalrAI
//
//  Created by Ciaran Liddy on 24/09/2025.
//

