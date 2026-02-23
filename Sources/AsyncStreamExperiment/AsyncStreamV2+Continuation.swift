//
// AsyncStreamV2+Continuation.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/12/26 at 12:28 AM
//

import Foundation

extension AsyncStreamV2 {
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
			case finished

			case cancelled
		}

		private let _storage: _Storage<Element, Failure>

		init(_storage: _Storage<Element, Failure>) {
			self._storage = _storage
		}

		@discardableResult
		public func yield() -> YieldResult where Element == Void {
			return self._storage.yield(()).convertToAsyncStreamYieldResult()
		}

		@discardableResult
		public func yield(with result: sending Result<Element, Never>) -> YieldResult {
			switch result {
			case let .success(value):
				return self._storage.yield(value).convertToAsyncStreamYieldResult()
			}
		}

		@discardableResult
		public func yield(_ value: sending Element) -> YieldResult {
			self._storage.yield(value).convertToAsyncStreamYieldResult()
		}

		public func finish() {
			self._storage.terminate(.finished(nil))
		}

		public var onTermination: (@Sendable (Termination) -> Void)? {
			get {
				convertToAsyncStreamOnTermination(self._storage.getOnTermination())
			}
			nonmutating set {
				self._storage.setOnTermination(convertToContinuationOnTermination(newValue))
			}
		}
	}
}

extension AsyncStreamV2.Continuation: Hashable {
	public func hash(into hasher: inout Hasher) {
		return hasher.combine(ObjectIdentifier(self._storage))
	}

	public static func == (lhs: AsyncStreamV2<Element>.Continuation, rhs: AsyncStreamV2<Element>.Continuation) -> Bool {
		return lhs._storage === rhs._storage
	}
}

extension AsyncStreamV2.Continuation.YieldResult: Sendable where Element: Sendable {}

extension AsyncStreamV2.Continuation.Termination: Hashable where Element: Hashable {}
