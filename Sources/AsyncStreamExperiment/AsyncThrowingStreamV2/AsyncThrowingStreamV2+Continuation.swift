
extension AsyncThrowingStreamV2 {
	public struct Continuation: Sendable {
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

		private let _storage: _Storage<Element, Failure>

		init(_storage: _Storage<Element, Failure>) {
			self._storage = _storage
		}

		public var onTermination: (@Sendable (Termination) -> Void)? {
			get {
				return convertToAsyncThrowingStreamOnTermination(self._storage.getOnTermination())
			}
			nonmutating set {
				self._storage.setOnTermination(convertToContinuationOnTermination(newValue))
			}
		}

		@discardableResult
		public func yield(_ value: sending Element) -> YieldResult {
			return self._storage.yield(value).convertToAsyncThrowingStreamYieldResult()
		}

		@discardableResult
		public func yield(with result: sending Result<Element, Failure>) -> YieldResult {
			switch result {
			case let .success(value):
				return self._storage.yield(value).convertToAsyncThrowingStreamYieldResult()

			case let .failure(failure):
				self._storage.terminate(.finished(failure))
				return .terminated
			}
		}

		public func finish(throwing error: Failure? = nil) {
			self._storage.terminate(.finished(error))
		}
	}
}

extension AsyncThrowingStreamV2.Continuation where Element == Void {
	@discardableResult
	public func yield() -> YieldResult {
		return self._storage.yield(Void()).convertToAsyncThrowingStreamYieldResult()
	}
}

extension AsyncThrowingStreamV2.Continuation: Hashable {
	public func hash(
		into hasher: inout Hasher) {
			return hasher.combine(ObjectIdentifier(self._storage))
		}

	public static func == (
		lsh: AsyncThrowingStreamV2.Continuation,
		rhs: AsyncThrowingStreamV2.Continuation)
	-> Bool {
		return lsh._storage === rhs._storage
	}
}

extension AsyncThrowingStreamV2.Continuation.BufferingPolicy: Hashable {}

extension AsyncThrowingStreamV2.Continuation.YieldResult: Sendable where Element: Sendable {}

extension AsyncThrowingStreamV2.Continuation.YieldResult: Equatable where Element: Equatable {}

extension AsyncThrowingStreamV2.Continuation.YieldResult: Hashable where Element: Hashable {}

extension AsyncThrowingStreamV2.Continuation.Termination: Equatable where Failure: Hashable {}

extension AsyncThrowingStreamV2.Continuation.Termination: Hashable where Failure: Hashable {}
