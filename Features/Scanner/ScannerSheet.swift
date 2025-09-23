import SwiftUI
import VisionKit

struct ScannerSheet: UIViewControllerRepresentable {
    var got: (String) -> Void
    func makeCoordinator() -> Coord { Coord(self) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }
    func updateUIViewController(_ ui: DataScannerViewController, context: Context) {}
    final class Coord: NSObject, DataScannerViewControllerDelegate {
        let parent: ScannerSheet
        private var didCapture = false
        init(_ p: ScannerSheet) { parent = p }
        func dataScanner(_ s: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didCapture else { return }
            if let code = addedItems.compactMap({ if case .barcode(let b) = $0 { b.payloadStringValue } else { nil } }).first {
                didCapture = true; parent.got(code); s.dismiss(animated: true)
            }
        }
        func dataScanner(_ s: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard !didCapture else { return }
            if case .barcode(let b) = item, let code = b.payloadStringValue {
                didCapture = true; parent.got(code); s.dismiss(animated: true)
            }
        }
    }
}
