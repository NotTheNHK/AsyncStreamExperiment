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

extension AsyncStreamV2.Continuation.YieldResult: Sendable where Element: Sendable {}
