
public struct AsyncStreamV2<Element> {
	private let _context: _Context<Element, Never>

	init(_context: _Context<Element, Never>) {
		self._context = _context
	}
}

extension AsyncStreamV2: @unchecked Sendable where Element: Sendable {}

extension AsyncStreamV2: AsyncSequence {
	public struct AsyncIterator: AsyncIteratorProtocol {
		private let _context: _Context<Element, Never>

		init(_context: _Context<Element, Never>) {
			self._context = _context
		}

		public func next(isolation actor: isolated (any Actor)? = #isolation) async -> Element? {
			return await self._context.produce()
		}
	}

	public func makeAsyncIterator() -> AsyncIterator {
		return AsyncIterator(_context: self._context)
	}
}

extension AsyncStreamV2 {
	public init(
		_ elementType: Element.Type = Element.self,
		bufferingPolicy: Continuation.BufferingPolicy = .unbounded,
		_ build: (Continuation) -> Void) {
			let _storage = _Storage(bufferPolicy: bufferingPolicy.convertToContinuationBufferingPolicy())

			self._context = _Context(_storage: _storage, produce: _storage.next)

			build(Continuation(_storage: _storage))
		}

	public static func makeStream(
		of elementType: Element.Type = Element.self,
		bufferingPolicy: Continuation.BufferingPolicy = .unbounded)
	-> (stream: AsyncStreamV2<Element>, continuation: Continuation) {
		let _storage = _Storage(bufferPolicy: bufferingPolicy.convertToContinuationBufferingPolicy())

		let continuation = AsyncStreamV2.Continuation(_storage: _storage)
		let stream = AsyncStreamV2(_context: _Context(_storage: _storage, produce: _storage.next))

		return (stream, continuation)
	}
}

extension AsyncStreamV2 {
	public init(
		unfolding produce: nonisolated(nonsending) sending @escaping () async -> Element?,
		onCancel: (@Sendable () -> Void)? = nil) {
			let _unfoldingStorage = _UnfoldingStorage(
				producer: produce,
				onCancel: onCancel)

			// Once `withTaskCancellationHandler` `nonisolated(nonsending)` change lands `produce` will inherit the callers executor.
			self._context = _Context {
				return await withTaskCancellationHandler {
					return await _unfoldingStorage.produce()
				} onCancel: {
					_unfoldingStorage.removeProduce()
					_unfoldingStorage.callOnCancel()
				}
			}
		}
}
