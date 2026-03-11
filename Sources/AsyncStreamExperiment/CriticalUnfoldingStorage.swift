
final class _CriticalUnfoldingStorage<Element, Failure: Error>: @unchecked Sendable {
	private let lock = Lock.create()

	private var producer: (nonisolated(nonsending) () async throws(Failure) -> Element?)?
	private var onCancel: (@Sendable () -> Void)?

	init(
		producer: nonisolated(nonsending) sending @escaping () async throws(Failure) -> Element?,
		onCancel: (@Sendable () -> Void)?) {
			self.producer = producer
			self.onCancel = onCancel
		}

	nonisolated(nonsending)
	func produce() async throws(Failure) -> Element? {
		lock.lock() // TODO: `withLock` crashes the compiler
		let producer = self.producer.take()
		lock.unlock()

		guard
			let result = try await producer?()
		else { return nil }

		lock.withLock {
			self.producer = producer
		}

		return result
	}

	func removeProduce() {
		lock.withLock {
			self.producer = nil
		}
	}

	func callOnCancel() {
		let onCancel = lock.withLock {
			self.onCancel.take()
		}

		onCancel?()
	}
}
