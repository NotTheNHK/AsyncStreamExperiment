//
// AsyncStreamV2.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/11/26 at 11:45 PM
//

import Foundation

public struct AsyncStreamV2<Element> {
	private let _context: _Context<Element, Never>

	init(_context: _Context<Element, Never>) {
		self._context = _context
	}
}

extension AsyncStreamV2: @unchecked Sendable where Element: Sendable {}

extension AsyncStreamV2: AsyncSequence {
	public typealias Element = Element
	public typealias Failure = Never

	public struct AsyncIterator: AsyncIteratorProtocol {
		private let _context: _Context<Element, Never>

		init(_context: _Context<Element, Never>) {
			self._context = _context
		}

		public func next(isolation actor: isolated (any Actor)?) async throws(Failure) -> Element? {
			await self._context.produce()
		}
	}

	public func makeAsyncIterator() -> AsyncIterator {
		AsyncIterator(_context: self._context)
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
	init(
		unfolding produce: nonisolated(nonsending) sending @escaping () async -> Element?,
		onCancel: (@Sendable () -> Void)? = nil) {
			self._context = _Context {
				return await withTaskCancellationHandler { // Once `withTaskCancellationHandler` `nonisolated(nonsending)` change lands `produce` will inherit the callers executor.
					await produce()
				} onCancel: {
					onCancel?()
				}
			}
		}
}
