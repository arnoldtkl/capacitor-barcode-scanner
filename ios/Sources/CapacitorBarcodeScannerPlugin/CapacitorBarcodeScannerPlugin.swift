// swiftlint:disable line_length
import Foundation
import Capacitor
import OSBarcodeLib

@objc(CapacitorBarcodeScannerPlugin)
public class CapacitorBarcodeScannerPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CapacitorBarcodeScannerPlugin"
    public let jsName = "CapacitorBarcodeScanner"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "scanBarcode", returnType: CAPPluginReturnPromise)
    ]
    var manager: OSBARCManagerProtocol?

    override public func load() {
        guard let viewController = self.bridge?.viewController else {
            CAPLog.print("Error (Barcode Plugin Load): Capacitor bridge or viewController is not initialized.")
            return
        }

        self.manager = OSBARCManagerFactory.createManager(with: viewController)
    }

    @objc func scanBarcode(_ call: CAPPluginCall) {
        if self.manager == nil {
            self.load()
        }

        guard let manager = self.manager else {
            call.sendError(with: OSBarcodeError.bridgeNotInitialized)
            return
        }

        guard let argumentsData = try? JSONSerialization.data(withJSONObject: call.jsObjectRepresentation),
              let scanArguments = try? JSONDecoder().decode(OSBARCScanParameters.self, from: argumentsData) else {
            call.sendError(with: OSBarcodeError.scanInputArgumentsIssue)
            return
        }

        // @MainActor ensures call.resolve() / call.sendError() are always called on the
        // main thread. Without it, the task resumes on Swift's cooperative thread pool
        // after the continuation, and Capacitor's bridge (WKWebView) is not thread-safe —
        // accessing it off-main crashes with EXC_BAD_ACCESS (code=1, address=0x20).
        Task { @MainActor in
            do {
                let scannedBarcode = try await manager.scanBarcode(with: scanArguments)
                call.resolve(["ScanResult": scannedBarcode.text, "format": scannedBarcode.format.rawValue])
            } catch OSBARCManagerError.cameraAccessDenied {
                call.sendError(with: OSBarcodeError.cameraAccessDenied)
            } catch OSBARCManagerError.scanningCancelled {
                call.sendError(with: OSBarcodeError.scanningCancelled)
            } catch {
                call.sendError(with: OSBarcodeError.scanningError)
            }
        }
    }
}

extension CAPPluginCall {

    func sendError(with error: OSBarcodeError) {
        self.reject(error.errorDescription, error.errorCode)
    }

}
