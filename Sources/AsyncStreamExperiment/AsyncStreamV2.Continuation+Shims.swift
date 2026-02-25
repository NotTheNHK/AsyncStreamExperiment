//
// AsyncStreamV2.Continuation+Shims.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/20/26 at 2:32 PM
//

import Foundation

extension AsyncStreamV2.Continuation.BufferingPolicy {
	func convertToContinuationBufferingPolicy() -> _Storage<Element, Never>.Continuation.BufferingPolicy {
		switch self {
		case .unbounded:
			return .unbounded
		case let .bufferingOldest(limit):
			return .bufferingOldest(limit)
		case let .bufferingNewest(limit):
			return .bufferingNewest(limit)
		}
	}
}

extension AsyncStreamV2.Continuation.Termination {
	func convertToContinuationTermination() -> _Storage<Element, Never>.Continuation.Termination {
		switch self {
		case .finished:
			return .finished(nil)
		case .cancelled:
			return .cancelled
		}
	}
}

extension AsyncStreamV2.Continuation {
	func convertToAsyncStreamOnTermination(
		_ onTermination: (@Sendable (_Storage<Element, Never>.Continuation.Termination) -> Void)?)
	-> (@Sendable (Termination) -> Void)? {
		{ @Sendable termination in
			onTermination?(termination.convertToContinuationTermination())
		}
	}

	func convertToContinuationOnTermination(
		_ onTermination: (@Sendable (Termination) -> Void)?)
	-> (@Sendable (_Storage<Element, Never>.Continuation.Termination) -> Void)? {
		{ @Sendable termination in
			onTermination?(termination.convertToAsyncStreamTermination())
		}
	}
}

extension _Storage.Continuation.BufferingPolicy {
	func convertToAsyncStreamBufferingPolicy() -> AsyncStreamV2<Element>.Continuation.BufferingPolicy {
		switch self {
		case .unbounded:
			return .unbounded
		case let .bufferingOldest(limit):
			return .bufferingOldest(limit)
		case let .bufferingNewest(limit):
			return .bufferingNewest(limit)
		}
	}
}

extension _Storage.Continuation.YieldResult {
	func convertToAsyncStreamYieldResult() -> AsyncStreamV2<Element>.Continuation.YieldResult {
		switch self {
		case let .enqueued(remaining):
			return .enqueued(remaining: remaining)
		case let .dropped(element):
			return .dropped(element)
		case .terminated:
			return .terminated
		}
	}
}

extension _Storage.Continuation.Termination {
	func convertToAsyncStreamTermination() -> AsyncStreamV2<Element>.Continuation.Termination {
		switch self {
		case .finished:
			return .finished
		case .cancelled:
			return .cancelled
		}
	}
}
