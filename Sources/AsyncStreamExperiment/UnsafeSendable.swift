//
// UnsafeSendable.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/13/26 at 6:15 PM
//

import Foundation

struct UnsafeSendable<Value: ~Copyable>: @unchecked Sendable, ~Copyable {
	private let value: Value

	init(_ value: consuming Value) {
		self.value = value
	}

	consuming func take() -> sending Value {
		return self.value
	}
}
