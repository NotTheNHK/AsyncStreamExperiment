//
// AsyncThrowingStreamV2.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/27/26 at 12:56 PM
//

import Foundation

public struct AsyncThrowingStreamV2<Element, Failure> where Failure : Error {
	private let _storage: _Storage<Element, Failure>

	init(_storage: _Storage<Element, Failure>) {
		self._storage = _storage
	}
}

extension AsyncThrowingStreamV2: Sendable where Element: Sendable {}

extension AsyncThrowingStreamV2: AsyncSequence {
	public typealias Element = Element
	public typealias Failure = Failure

	public struct AsyncIterator: AsyncIteratorProtocol {
		private let _storage: _Storage<Element, Failure>

		init(_storage: _Storage<Element, Failure>) {
			self._storage = _storage
		}

		public func next(isolation actor: isolated (any Actor)?) async throws(Failure) -> Element? {
			try await self._storage.next()
		}
	}

	public func makeAsyncIterator() -> AsyncIterator {
		AsyncIterator(_storage: self._storage)
	}
}

extension AsyncThrowingStreamV2 {
	init(
		_ elementType: Element.Type = Element.self,
		bufferingPolicy: AsyncThrowingStreamV2<Element, Failure>.Continuation.BufferingPolicy = .unbounded,
		_ build: (AsyncThrowingStreamV2<Element, Failure>.Continuation) -> Void) {
			let _storage = _Storage(bufferPolicy: bufferingPolicy.convertToContinuationBufferingPolicy())

			self._storage = _storage

			build(Continuation(_storage: _storage))
		}

	static func makeStream(
		of elementType: Element.Type = Element.self,
		throwing failureType: Failure.Type = Failure.self,
		bufferingPolicy: AsyncThrowingStreamV2<Element, Failure>.Continuation.BufferingPolicy = .unbounded)
	-> (stream: AsyncThrowingStreamV2<Element, Failure>, continuation: AsyncThrowingStreamV2<Element, Failure>.Continuation) {
		let _storage = _Storage(bufferPolicy: bufferingPolicy.convertToContinuationBufferingPolicy())

		let continuation = AsyncThrowingStreamV2.Continuation(_storage: _storage)
		let stream = AsyncThrowingStreamV2(_storage: _storage)

		return (stream, continuation)
	}
}
