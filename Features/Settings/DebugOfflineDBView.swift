import SwiftUI

struct DebugOfflineDBView: View {
    @Environment(\.appEnvironment) private var env
    @State private var report: LocalFoodDatabase.DebugReport?
    @State private var statusMessage: String = ""
    @State private var sampleQuery: String = "milk"
    @State private var bundlePath: String = "—"
    @State private var bundleExists: Bool = false
    @State private var bundleSize: Int64? = nil
    @State private var barcodeQuery: String = ""
    @State private var tempDb: LocalFoodDatabase?

    var body: some View {
        Form {
            Section("Bundle DB") {
                labeled("Path", bundlePath)
                labeled("Exists", bundleExists ? "Yes" : "No")
                labeled("Size", byteString(bundleSize))
            }

            Section("Opened DB") {
                if let report {
                    labeled("Path", report.path)
                    labeled("Exists", report.exists ? "Yes" : "No")
                    labeled("Size", byteString(report.fileSize))
                    labeled("Tables", report.tables.joined(separator: ", "))
                    labeled("foods", report.foodsCount.map(String.init) ?? "—")
                    labeled("foods_fts", report.foodsFTSCount.map(String.init) ?? "—")
                } else if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No database opened")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Sample Search") {
                TextField("Query", text: $sampleQuery)
                Button("Run Search") {
                    refreshReport()
                }
                if let report {
                    ForEach(report.sampleResults.prefix(10)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                            if let brand = item.brand, !brand.isEmpty {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Barcode Test") {
                TextField("Barcode", text: $barcodeQuery)
                    .keyboardType(.numberPad)
                Button("Lookup Barcode") {
                    let db = env.offlineDatabase ?? tempDb
                    if let result = db?.lookupBarcode(barcodeQuery) {
                        statusMessage = "Barcode hit: \(result.name)"
                    } else {
                        statusMessage = "Barcode miss"
                    }
                }
            }

            Section("Actions") {
                Button("Open Bundled DB") {
                    do {
                        tempDb = try LocalFoodDatabase.bundled()
                        statusMessage = "Opened bundled DB via debug view"
                        refreshReport()
                    } catch {
                        statusMessage = "Failed to open bundled DB: \(error)"
                    }
                }
            }
        }
        .navigationTitle("Debug Offline DB")
        .task { refreshReport() }
    }

    private func refreshReport() {
        let bundleUrl = Bundle.main.url(forResource: "offline_foods", withExtension: "sqlite")
        if let url = bundleUrl {
            bundlePath = url.path
            bundleExists = FileManager.default.fileExists(atPath: url.path)
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            bundleSize = (attrs?[.size] as? NSNumber)?.int64Value
        } else {
            bundlePath = "Not found in bundle"
            bundleExists = false
            bundleSize = nil
        }
        if let db = env.offlineDatabase ?? tempDb {
            report = db.debugReport(sampleQuery: sampleQuery)
            statusMessage = ""
        } else {
            report = nil
            statusMessage = "No DB instance in environment"
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func byteString(_ size: Int64?) -> String {
        guard let size else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

#Preview {
    NavigationStack {
        DebugOfflineDBView()
    }
}
