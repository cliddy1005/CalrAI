import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var env

    @StateObject private var vm = SearchViewModel()

    var pick: (Product) -> Void

    var body: some View {
        NavigationStack {
            List {
                if vm.loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                ForEach(vm.results) { p in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(p.name)
                            if let g = p.nutriScore {
                                Text(g.uppercased())
                                    .font(.caption2)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                        if let kcal = p.kcalPer100g {
                            Text("\(Int(kcal)) kcal / 100 g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await choose(p) }
                    }
                }

                if !vm.loading && vm.results.isEmpty && vm.query.count >= 3 {
                    Text("No matches")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Search food")
            .searchable(text: $vm.query, prompt: "Start typing…")
            // ✅ iOS 17 syntax — no newValue parameter
            .onChange(of: vm.query) {
                Task { await vm.performSearch(using: env) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private func choose(_ lite: ProductLite) async {
        do {
            let p = try await env.foodRepository.lookupBarcode(lite.barcode)
            pick(p)
        } catch {
            pick(Product(
                barcode: lite.barcode,
                name: lite.name,
                kcalPer100g: lite.kcalPer100g ?? 0,
                proteinPer100g: nil,
                fatPer100g: nil,
                carbPer100g: nil,
                servingSizeGrams: nil,
                nutriScore: lite.nutriScore
            ))
        }
        dismiss()
    }
}

