import Foundation

/// Any 型の値を JSON エンコード/デコード可能にするラッパー型です。
///
/// 動的な JSON を扱う場合に利用します。
struct AnyCodable: Codable {
  let value: Any

  init(_ value: Any) {
    self.value = value
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    // JSONSerialization の Bool は NSNumber としてブリッジされるため、
    // Bool と数値の区別には Core Foundation の型判定を使う。
    if let numberValue = value as? NSNumber,
      CFGetTypeID(numberValue) == CFBooleanGetTypeID()
    {
      try container.encode(numberValue.boolValue)
    } else if let intValue = value as? Int {
      try container.encode(intValue)
    } else if let doubleValue = value as? Double {
      try container.encode(doubleValue)
    } else if let stringValue = value as? String {
      try container.encode(stringValue)
    } else if let boolValue = value as? Bool {
      try container.encode(boolValue)
    } else if let arrayValue = value as? [Any] {
      try container.encode(arrayValue.map(AnyCodable.init))
    } else if let dictValue = value as? [String: Any] {
      let mapped = dictValue.mapValues(AnyCodable.init)
      try container.encode(mapped)
    } else if value is NSNull {
      try container.encodeNil()
    } else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "AnyCodable cannot encode \(type(of: value))"
        ))
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      value = NSNull()
    } else if let boolValue = try? container.decode(Bool.self) {
      value = boolValue
    } else if let intValue = try? container.decode(Int.self) {
      value = intValue
    } else if let doubleValue = try? container.decode(Double.self) {
      value = doubleValue
    } else if let stringValue = try? container.decode(String.self) {
      value = stringValue
    } else if let arrayValue = try? container.decode([AnyCodable].self) {
      value = arrayValue.map(\.value)
    } else if let dictValue = try? container.decode([String: AnyCodable].self) {
      value = dictValue.mapValues(\.value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Cannot decode AnyCodable")
    }
  }
}
