import CoreGraphics
import Foundation
// prints "id width height layer" for each on-screen window of the pid given
let pid = Int(CommandLine.arguments[1])!
for w in (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]) where w[kCGWindowOwnerPID as String] as? Int == pid {
    let b = w[kCGWindowBounds as String] as! [String: Any]
    print(w[kCGWindowNumber as String]!, b["Width"]!, b["Height"]!, w[kCGWindowLayer as String]!)
}
