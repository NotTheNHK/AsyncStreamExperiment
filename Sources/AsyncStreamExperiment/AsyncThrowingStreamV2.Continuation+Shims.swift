//
// AsyncThrowingStreamV2.Continuation+Shims.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/27/26 at 1:03 PM
//

import Foundation

extension AsyncThrowingStreamV2.Continuation.BufferingPolicy {
	func convertToContinuationBufferingPolicy() -> _Storage<Element, Failure>.Continuation.BufferingPolicy {
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

extension AsyncThrowingStreamV2.Continuation.Termination {
	func convertToContinuationTermination() -> _Storage<Element, Failure>.Continuation.Termination {
		switch self {
		case .finished:
			return .finished(nil)
		case .cancelled:
			return .cancelled
		}
	}
}

extension AsyncThrowingStreamV2.Continuation {
	func convertToAsyncThrowingStreamOnTermination(
		_ onTermination: (@Sendable (_Storage<Element, Failure>.Continuation.Termination) -> Void)?)
	-> (@Sendable (Termination) -> Void)? {
		{ @Sendable termination in
			onTermination?(termination.convertToContinuationTermination())
		}
	}

	func convertToContinuationOnTermination(
		_ onTermination: (@Sendable (Termination) -> Void)?)
	-> (@Sendable (_Storage<Element, Failure>.Continuation.Termination) -> Void)? {
		{ @Sendable termination in
			onTermination?(termination.convertToAsyncThrowingStreamTermination())
		}
	}
}

extension _Storage.Continuation.BufferingPolicy {
	func convertToAsyncThrowingStreamBufferingPolicy() -> AsyncThrowingStreamV2<Element, Failure>.Continuation.BufferingPolicy {
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
	func convertToAsyncThrowingStreamYieldResult() -> AsyncThrowingStreamV2<Element, Failure>.Continuation.YieldResult {
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
	func convertToAsyncThrowingStreamTermination() -> AsyncThrowingStreamV2<Element, Failure>.Continuation.Termination {
		switch self {
		case let .finished(failure):
			return .finished(failure)
		case .cancelled:
			return .cancelled
		}
	}
}
