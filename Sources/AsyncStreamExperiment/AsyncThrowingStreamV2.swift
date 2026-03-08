//
// AsyncThrowingStreamV2.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/27/26 at 12:56 PM
//

import Foundation

public struct AsyncThrowingStreamV2<Element, Failure: Error> {
	private let _context: _Context<Element, Failure>

	init(_context: _Context<Element, Failure>) {
		self._context = _context
	}
}

extension AsyncThrowingStreamV2: @unchecked Sendable where Element: Sendable {}

extension AsyncThrowingStreamV2: AsyncSequence {
	public typealias Element = Element
	public typealias Failure = Failure

	public struct AsyncIterator: AsyncIteratorProtocol {
		private let _context: _Context<Element, Failure>

		init(_context: _Context<Element, Failure>) {
			self._context = _context
		}

		public func next(isolation actor: isolated (any Actor)?) async throws(Failure) -> Element? {
			try await self._context.produce()
		}
	}

	public func makeAsyncIterator() -> AsyncIterator {
		AsyncIterator(_context: self._context)
	}
}

extension AsyncThrowingStreamV2 {
	public init(
		_ elementType: Element.Type = Element.self,
		_ failureType: Failure.Type = Failure.self,
		bufferingPolicy: Continuation.BufferingPolicy = .unbounded,
		_ build: (Continuation) -> Void) {
			let _storage = _Storage(bufferPolicy: bufferingPolicy.convertToContinuationBufferingPolicy())

			self._context = _Context(_storage: _storage, produce: _storage.next)

			build(Continuation(_storage: _storage))
		}

	public static func makeStream(
		of elementType: Element.Type = Element.self,
		throwing failureType: Failure.Type = Failure.self,
		bufferingPolicy: Continuation.BufferingPolicy = .unbounded)
	-> (stream: AsyncThrowingStreamV2<Element, Failure>, continuation: Continuation) {
		let _storage = _Storage(bufferPolicy: bufferingPolicy.convertToContinuationBufferingPolicy())

		let continuation = AsyncThrowingStreamV2.Continuation(_storage: _storage)
		let stream = AsyncThrowingStreamV2(_context: _Context(_storage: _storage, produce: _storage.next))

		return (stream, continuation)
	}
}

extension AsyncThrowingStreamV2 where Failure == any Error {
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
	-> (stream: AsyncThrowingStreamV2<Element, Failure>, continuation: Continuation) {
		let _storage = _Storage(bufferPolicy: bufferingPolicy.convertToContinuationBufferingPolicy())

		let continuation = AsyncThrowingStreamV2.Continuation(_storage: _storage)
		let stream = AsyncThrowingStreamV2(_context: _Context(_storage: _storage, produce: _storage.next))

		return (stream, continuation)
	}
}

extension AsyncThrowingStreamV2 {
	public init(
		unfolding produce: nonisolated(nonsending) sending @escaping () async throws(Failure) -> Element?,
		onCancel: (@Sendable () -> Void)? = nil) {
			let thunk: nonisolated(nonsending) () async throws(Failure) -> Element? = {
				let result: Result<Element?, Failure> = await withTaskCancellationHandler { // Once `withTaskCancellationHandler`'s `nonisolated(nonsending)` change lands `produce` will inherit the callers executor.
					do throws(Failure) {
						return try await .success(produce())
					} catch {
						return .failure(error)
					}
				} onCancel: {
					onCancel?()
				}

				return try result.get()
			}

			self._context = _Context(produce: thunk)
		}
}

extension AsyncThrowingStreamV2 where Failure == any Error {
	public init(
		unfolding produce: nonisolated(nonsending) sending @escaping () async throws(Failure) -> Element?,
		onCancel: (@Sendable () -> Void)? = nil) {
			self._context = _Context {
				return try await withTaskCancellationHandler {
					try await produce()
				} onCancel: {
					onCancel?()
				}
			}
		}
}
