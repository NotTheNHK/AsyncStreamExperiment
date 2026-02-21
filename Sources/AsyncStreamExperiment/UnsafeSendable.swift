//
// UnsafeSendable.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/13/26 at 6:15 PM
//

import Foundation

struct UnsafeSendable<Value>: @unchecked Sendable {
	private var consumed = false
	private let value: Value

	init(_ value: Value) {
		self.value = value
	}

	consuming func take() -> sending Value {
		precondition(
			self.consumed == false,
			"Attempted to consume nonsendable 'value' more than once")

		self.consumed = true

		return self.value
	}
}
