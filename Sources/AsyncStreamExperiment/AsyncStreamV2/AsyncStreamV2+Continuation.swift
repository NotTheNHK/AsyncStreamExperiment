
extension AsyncStreamV2 {
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
			case finished

			case cancelled
		}

		private let _context: _ContinuationContext<Element, Never>

		init(_storage: _Storage<Element, Failure>) {
			self._context = _ContinuationContext(_storage: _storage)
		}

		public var onTermination: (@Sendable (Termination) -> Void)? {
			get {
				return convertToAsyncStreamOnTermination(self._context._storage.getOnTermination())
			}
			nonmutating set {
				self._context._storage.setOnTermination(convertToContinuationOnTermination(newValue))
			}
		}

		@discardableResult
		public func yield(_ value: sending Element) -> YieldResult {
			return self._context._storage.yield(value).convertToAsyncStreamYieldResult()
		}

		@discardableResult
		public func yield(with result: sending Result<Element, Never>) -> YieldResult {
			switch result {
			case let .success(value):
				return self._context._storage.yield(value).convertToAsyncStreamYieldResult()
			}
		}

		public func finish() {
			self._context._storage.terminate(.finished(nil))
		}
	}
}

extension AsyncStreamV2.Continuation where Element == Void {
	@discardableResult
	public func yield() -> YieldResult {
		return self._context._storage.yield(Void()).convertToAsyncStreamYieldResult()
	}
}

extension AsyncStreamV2.Continuation: Hashable {
	public func hash(
		into hasher: inout Hasher) {
			return hasher.combine(ObjectIdentifier(self._context._storage))
		}

	public static func == (
		lhs: AsyncStreamV2<Element>.Continuation,
		rhs: AsyncStreamV2<Element>.Continuation)
	-> Bool {
		return lhs._context._storage === rhs._context._storage
	}
}

extension AsyncStreamV2.Continuation.BufferingPolicy: Hashable {}

extension AsyncStreamV2.Continuation.YieldResult: Sendable where Element: Sendable {}

extension AsyncStreamV2.Continuation.YieldResult: Equatable where Element: Equatable {}

extension AsyncStreamV2.Continuation.YieldResult: Hashable where Element: Hashable {}

extension AsyncStreamV2.Continuation.Termination: Hashable where Element: Hashable {}
