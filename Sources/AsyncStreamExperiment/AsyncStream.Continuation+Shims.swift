//
// AsyncStreamV2.Continuation+Shims.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/20/26 at 2:32 PM
//

import Foundation

extension AsyncStreamV2.Continuation.BufferingPolicy {
	func convertToContinuationBufferingPolicy() -> Continuation<Element, Never>.BufferingPolicy {
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
	func convertToContinuationTermination() -> Continuation<Element, Never>.Termination {
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
		_ onTermination: (@Sendable (Continuation<Element, Never>.Termination) -> Void)?)
	-> (@Sendable (Termination) -> Void)? {
		{ @Sendable termination in
			onTermination?(termination.convertToContinuationTermination())
		}
	}

	func convertToContinuationOnTermination(
		_ onTermination: (@Sendable (Termination) -> Void)?)
	-> (@Sendable (Continuation<Element, Never>.Termination) -> Void)? {
		{ @Sendable termination in
			onTermination?(termination.convertToAsyncStreamTermination())
		}
	}
}

extension Continuation.BufferingPolicy {
	func convertToAsyncStreamBufferingPolicy() -> AsyncStreamV2<Element>.Continuation.BufferingPolicy {
		switch self {
		case .unbounded:
			return .unbounded
		case .bufferingOldest(let limit):
			return .bufferingOldest(limit)
		case .bufferingNewest(let limit):
			return .bufferingNewest(limit)
		}
	}
}

extension Continuation.YieldResult {
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

extension Continuation.Termination {
	func convertToAsyncStreamTermination() -> AsyncStreamV2<Element>.Continuation.Termination {
		switch self {
		case .finished:
			return .finished
		case .cancelled:
			return .cancelled
		}
	}
}
