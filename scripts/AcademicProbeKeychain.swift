import Foundation
import Security

// Private IPC helper. Payloads are never accepted as command-line arguments.
// The Python parent captures stdout in memory; direct terminal output is refused.
func stop(_ code: Int32) -> Never { exit(code) }
guard isatty(STDIN_FILENO) == 0, isatty(STDOUT_FILENO) == 0 else { stop(2) }
let data = FileHandle.standardInput.readDataToEndOfFile()
guard let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let action = request["action"] as? String,
      let account = request["account"] as? String, !account.isEmpty else { stop(2) }

let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.xujk.NTPUOne.AcademicProbe",
    kSecAttrAccount as String: account,
    kSecAttrSynchronizable as String: false
]
var output: [String: Any] = [:]
switch action {
case "store":
    guard let payload = request["payload"] as? [String: Any],
          let encoded = try? JSONSerialization.data(withJSONObject: payload) else { stop(2) }
    let update = [kSecValueData as String: encoded]
    var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if status == errSecItemNotFound {
        var item = query
        item[kSecValueData as String] = encoded
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else { stop(3) }
case "load":
    var read = query
    read[kSecReturnData as String] = true
    read[kSecMatchLimit as String] = kSecMatchLimitOne
    var value: CFTypeRef?
    let status = SecItemCopyMatching(read as CFDictionary, &value)
    if status == errSecItemNotFound { output["payload"] = NSNull() }
    else {
        guard status == errSecSuccess, let encoded = value as? Data,
              let payload = try? JSONSerialization.jsonObject(with: encoded) else { stop(3) }
        output["payload"] = payload
    }
case "delete":
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { stop(3) }
default:
    stop(2)
}
guard let result = try? JSONSerialization.data(withJSONObject: output) else { stop(2) }
FileHandle.standardOutput.write(result)
