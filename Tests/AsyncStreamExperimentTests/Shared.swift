struct SomeError: Error, Equatable {
	var value = Int.random(in: 0..<100)
}

class NotSendable {}
