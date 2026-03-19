
extension AsyncThrowingStreamV2 {
	public struct Continuation: @unchecked Sendable {
		public enum BufferingPolicy: Sendable {
			case unbounded

			case bufferingOldest(Int)

			case bufferingNewest(Int)
		}

		public enum YieldResult {
			case enqueued(remaining: Int)

			case dropped(Element)

			case terminated
		}

		public enum Termination: Sendable {
			case finished(Failure?)

			case cancelled
		}

		private let _context: _ContinuationContext<Element, Failure>

		init(_storage: _Storage<Element, Failure>) {
			self._context = _ContinuationContext(_storage: _storage)
		}

		public var onTermination: (@Sendable (Termination) -> Void)? {
			get {
				return adaptToStreamTerminationHandler(self._context._storage.getOnTermination())
			}
			nonmutating set {
				self._context._storage.setOnTermination(adaptToStorageTerminationHandler(newValue))
			}
		}

		@discardableResult
		public func yield(_ value: sending Element) -> YieldResult {
			return self._context._storage.yield(value).asStreamYieldResult()
		}

		@discardableResult
		public func yield(with result: sending Result<Element, Failure>) -> YieldResult {
			switch result {
			case let .success(value):
				return self._context._storage.yield(value).asStreamYieldResult()

			case let .failure(failure):
				self._context._storage.terminate(.finished(failure))
				return .terminated
			}
		}

		public func finish(throwing error: Failure? = nil) {
			self._context._storage.terminate(.finished(error))
		}
	}
}

extension AsyncThrowingStreamV2.Continuation where Element == Void {
	@discardableResult
	public func yield() -> YieldResult {
		return self._context._storage.yield(Void()).asStreamYieldResult()
	}
}

extension AsyncThrowingStreamV2.Continuation: Hashable {
	public func hash(
		into hasher: inout Hasher) {
			return hasher.combine(ObjectIdentifier(self._context._storage))
		}

	public static func == (
		lsh: AsyncThrowingStreamV2.Continuation,
		rhs: AsyncThrowingStreamV2.Continuation)
	-> Bool {
		return lsh._context._storage === rhs._context._storage
	}
}

extension AsyncThrowingStreamV2.Continuation.BufferingPolicy: Hashable {}

extension AsyncThrowingStreamV2.Continuation.YieldResult: Sendable where Element: Sendable {}

extension AsyncThrowingStreamV2.Continuation.YieldResult: Equatable where Element: Equatable {}

extension AsyncThrowingStreamV2.Continuation.YieldResult: Hashable where Element: Hashable {}

extension AsyncThrowingStreamV2.Continuation.Termination: Equatable where Failure: Hashable {}

extension AsyncThrowingStreamV2.Continuation.Termination: Hashable where Failure: Hashable {}
