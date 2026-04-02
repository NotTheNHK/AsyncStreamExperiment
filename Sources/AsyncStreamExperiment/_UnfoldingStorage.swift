
final class _UnfoldingStorage<Element, Failure: Error>: @unchecked Sendable {
	private let lock: Lock

	private var producer: (nonisolated(nonsending) () async throws(Failure) -> Element?)?
	private var onCancel: (@Sendable () -> Void)?

	init(
		producer: nonisolated(nonsending) sending @escaping () async throws(Failure) -> Element?,
		onCancel: (@Sendable () -> Void)?) {
			self.lock = .create()
			self.producer = producer
			self.onCancel = onCancel
		}

	deinit {
		Lock.destroy(lock)
	}

	nonisolated(nonsending)
	func produce() async throws(Failure) -> Element? {
		lock.lock() // TODO: `withLock` crashes the compiler here
		let producer = self.producer.take()
		lock.unlock()

		guard
			let result = try await producer?()
		else { return nil }

		withLock {
			self.producer = producer
		}

		return result
	}

	func removeProduce() {
		withLock {
			self.producer = nil
		}
	}

	func callOnCancel() {
		let onCancel = withLock {
			return self.onCancel.take()
		}

		onCancel?()
	}
}

extension _UnfoldingStorage {
  func withLock<Value>(_ action: () -> Value) -> Value {
    lock.lock()

    defer { lock.unlock() }

    return action()
  }
}
