import SwiftUI

struct SearchView: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: SearchViewModel
    var pick: (Product) -> Void
    @State private var searchTask: Task<Void, Never>? = nil

    init(pick: @escaping (Product) -> Void) {
        self._vm = StateObject(wrappedValue: SearchViewModel(search: AppEnvironment.live.search,
                                                             location: AppEnvironment.live.location))
        self.pick = pick
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ShopsStrip(stores: vm.stores)
                List {
                    if vm.loading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
                    ForEach(vm.results) { p in
                        ProductRow(product: p)
                            .contentShape(Rectangle())
                            .onTapGesture { Task { await choose(p) } }
                    }
                    if !vm.loading && vm.results.isEmpty && vm.query.trimmingCharacters(in: .whitespaces).count >= 2 {
                        Text("No matches").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Search food")
            .searchable(text: $vm.query, prompt: "Start typing…")
            .onChange(of: vm.query) { newValue in
                searchTask?.cancel()
                searchTask = Task {
                    do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
                    await vm.performSearch()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Use Location") { vm.askLocation() }
                }
            }
            .task {
                vm.askLocation()
                await vm.refreshGeoContext()
            }
        }
    }

    private func choose(_ lite: ProductLite) async {
        if let p = try? await env.search.product(code: lite.barcode) {
            pick(p); dismiss()
        }
    }
}
