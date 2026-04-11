
public struct AsyncThrowingStreamV2<Element, Failure: Error> {
	private let _context: _StreamContext<Element, Failure>

	init(_context: _StreamContext<Element, Failure>) {
		self._context = _context
	}
}

extension AsyncThrowingStreamV2: @unchecked Sendable where Element: Sendable {}

extension AsyncThrowingStreamV2: AsyncSequence {
	public struct AsyncIterator: AsyncIteratorProtocol {
		private let _context: _StreamContext<Element, Failure>

		init(_context: _StreamContext<Element, Failure>) {
			self._context = _context
		}

		public func next(isolation actor: isolated (any Actor)? = #isolation) async throws(Failure) -> Element? {
			return try await self._context.produce()
		}
	}

	public func makeAsyncIterator() -> AsyncIterator {
		return AsyncIterator(_context: self._context)
	}
}

extension AsyncThrowingStreamV2 {
	public init(
		_ elementType: Element.Type = Element.self,
		_ failureType: Failure.Type = Failure.self,
		bufferingPolicy: Continuation.BufferingPolicy = .unbounded,
		_ build: (Continuation) -> Void) {
			let _storage = _Storage(bufferingPolicy: bufferingPolicy.asStorageBufferingPolicy())

			self._context = _StreamContext(_storage: _storage, produce: _storage.next)

			build(Continuation(_storage: _storage))
		}

	public static func makeStream(
		of elementType: Element.Type = Element.self,
		throwing failureType: Failure.Type = Failure.self,
		bufferingPolicy: Continuation.BufferingPolicy = .unbounded)
	-> (stream: AsyncThrowingStreamV2<Element, Failure>, continuation: Continuation) {
		let _storage = _Storage(bufferingPolicy: bufferingPolicy.asStorageBufferingPolicy())

		let continuation = AsyncThrowingStreamV2.Continuation(_storage: _storage)
		let stream = AsyncThrowingStreamV2(_context: _StreamContext(_storage: _storage, produce: _storage.next))

		return (stream, continuation)
	}
}

extension AsyncThrowingStreamV2 where Failure == any Error {
	public init(
		_ elementType: Element.Type = Element.self,
		bufferingPolicy: Continuation.BufferingPolicy = .unbounded,
		_ build: (Continuation) -> Void) {
			let _storage = _Storage(bufferingPolicy: bufferingPolicy.asStorageBufferingPolicy())

			self._context = _StreamContext(_storage: _storage, produce: _storage.next)

			build(Continuation(_storage: _storage))
		}

	public static func makeStream(
		of elementType: Element.Type = Element.self,
		bufferingPolicy: Continuation.BufferingPolicy = .unbounded)
	-> (stream: AsyncThrowingStreamV2<Element, Failure>, continuation: Continuation) {
		let _storage = _Storage(bufferingPolicy: bufferingPolicy.asStorageBufferingPolicy())

		let continuation = AsyncThrowingStreamV2.Continuation(_storage: _storage)
		let stream = AsyncThrowingStreamV2(_context: _StreamContext(_storage: _storage, produce: _storage.next))

		return (stream, continuation)
	}
}

extension AsyncThrowingStreamV2 {
  public init(
    unfolding produce: nonisolated(nonsending) sending @escaping () async throws(Failure) -> Element?,
    onCancel: (@Sendable () -> Void)? = nil) {
      let _unfoldingStorage = _UnfoldingStorage(
        producer: produce,
        onCancel: onCancel)

      // Once `withTaskCancellationHandler` adopts `nonisolated(nonsending)` `produce` will inherit the callers executor.
      let thunk: nonisolated(nonsending) () async throws(Failure) -> Element? = {
        let result: Result<Element?, Failure> = await withTaskCancellationHandler {
          do throws(Failure) {
            return try await .success(_unfoldingStorage.next())
          } catch {
            return .failure(error)
          }
        } onCancel: {
          _unfoldingStorage.terminate()
        }

        return try result.get()
      }

      self._context = _StreamContext(produce: thunk)
    }
}

extension AsyncThrowingStreamV2 where Failure == any Error {
  public init(
    unfolding produce: nonisolated(nonsending) sending @escaping () async throws(Failure) -> Element?,
    onCancel: (@Sendable () -> Void)? = nil) {
      let _unfoldingStorage = _UnfoldingStorage(
        producer: produce,
        onCancel: onCancel)

      // Once `withTaskCancellationHandler` adopts `nonisolated(nonsending)` `produce` will inherit the callers executor.
      self._context = _StreamContext {
        return try await withTaskCancellationHandler {
          return try await _unfoldingStorage.next()
        } onCancel: {
          _unfoldingStorage.terminate()
        }
      }
    }
}
