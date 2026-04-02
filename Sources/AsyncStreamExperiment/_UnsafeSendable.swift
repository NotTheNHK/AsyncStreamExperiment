
struct _UnsafeSendable<Value: ~Copyable>: @unchecked Sendable, ~Copyable {
	private let value: Value

	init(_ value: consuming Value) {
		self.value = value
	}

	consuming func take() -> sending Value {
		return self.value
	}
}

struct Disconnected<Value: ~Copyable>: ~Copyable, Sendable {
  // This is safe since we take the value as sending and take consumes it
  // and returns it as sending.
  private nonisolated(unsafe) var value: Value?

  @usableFromInline
  init(value: consuming sending Value) {
    self.value = .some(value)
  }

  @usableFromInline
  consuming func take() -> sending Value {
    nonisolated(unsafe) let value = self.value.take()!
    return value
  }

  @usableFromInline
  mutating func swap(newValue: consuming sending Value) -> sending Value {
    nonisolated(unsafe) let value = self.value.take()!
    self.value = consume newValue
    return value
  }
}
