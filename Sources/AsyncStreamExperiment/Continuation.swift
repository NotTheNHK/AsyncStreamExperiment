//
// Continuation.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/12/26 at 4:13 PM
//

import Foundation

struct Continuation<Element, Failure: Error> {
	enum BufferingPolicy: Sendable {
		case unbounded

		case bufferingOldest(Int)

		case bufferingNewest(Int)
	}

	enum YieldResult {
		case enqueued(remaining: Int)

		case dropped(Element)

		case terminated
	}

	enum Termination: Sendable {
		case finished(Failure?)

		case cancelled
	}
}
