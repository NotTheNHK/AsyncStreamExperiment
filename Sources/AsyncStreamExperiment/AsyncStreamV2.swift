//
// AsyncStreamV2.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/11/26 at 11:45 PM
//

import Foundation

public struct AsyncStreamV2<Element> {
	private let _storage: _Storage<Element, Never>

	init(_storage: _Storage<Element, Never>) {
		self._storage = _storage
	}
}

extension AsyncStreamV2: Sendable where Element: Sendable {}

extension AsyncStreamV2: AsyncSequence {
	public typealias Element = Element
	public typealias Failure = Never

	public struct AsyncIterator: AsyncIteratorProtocol {
		private let _storage: _Storage<Element, Never>

		init(_storage: _Storage<Element, Never>) {
			self._storage = _storage
		}

		public func next(isolation actor: isolated (any Actor)?) async throws(Failure) -> Element? {
			await self._storage.next()
		}
	}

	public func makeAsyncIterator() -> AsyncIterator {
		AsyncIterator(_storage: self._storage)
	}
}

extension AsyncStreamV2 {
	public init(
		_ elementType: Element.Type = Element.self,
		bufferingPolicy: Continuation.BufferingPolicy = .unbounded,
		_ build: (Continuation) -> Void) {
			let _storage = _Storage(bufferPolicy: bufferingPolicy.convertToContinuationBufferingPolicy())

			self._storage = _storage

			build(Continuation(_storage: _storage))
		}

	public static func makeStream(
		of elementType: Element.Type = Element.self,
		bufferingPolicy: AsyncStreamV2<Element>.Continuation.BufferingPolicy = .unbounded)
	-> (stream: AsyncStreamV2<Element>, continuation: AsyncStreamV2<Element>.Continuation) {
		let _storage = _Storage(bufferPolicy: bufferingPolicy.convertToContinuationBufferingPolicy())

		let continuation = AsyncStreamV2.Continuation(_storage: _storage)
		let stream = AsyncStreamV2(_storage: _storage)

		return (stream, continuation)
	}
}
