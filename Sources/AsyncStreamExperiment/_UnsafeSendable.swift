
struct UnsafeSendable<Value: ~Copyable>: ~Copyable, @unchecked Sendable {
  private var value: Value?

  init(value: consuming Value) {
    self.value = .some(value)
  }

  consuming func take() -> sending Value {
    return self.value.take()!
  }

  mutating func swap(newValue: consuming sending Value) -> sending Value {
    let value = self.value.take()!
    self.value = consume newValue
    return value
  }
}
