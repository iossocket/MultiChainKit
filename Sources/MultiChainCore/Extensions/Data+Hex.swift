import Foundation

extension Data {
  var hexString: String {
    return "0x\(self.toHexString())"
  }
}