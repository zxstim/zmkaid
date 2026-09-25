import Foundation
import IOKit

/// Whether the keyboard's left half is plugged into this Mac by USB. Only the left half does USB; the right half's
/// port just charges it.
enum USBPresence {
    /// ZMK's default USB vendor / product IDs, plus the keyboard's name to tell it from other ZMK boards.
    static func isConnected(productName: String) -> Bool {
        let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        matching["idVendor"] = 0x1D50
        matching["idProduct"] = 0x615E
        matching["USB Product Name"] = productName
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return false }
        IOObjectRelease(service)
        return true
    }
}
