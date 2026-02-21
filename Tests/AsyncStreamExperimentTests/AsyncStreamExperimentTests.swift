import Testing
@testable import AsyncStreamExperiment

struct SomeError: Error, Equatable {
	var value = Int.random(in: 0..<100)
}

class NotSendable {}

struct AsyncStreamV2Tests {
	@Test("factory method")
	func factoryMethod() async {
		let (stream, continuation) = AsyncStreamV2.makeStream(of: String.self)
		continuation.yield("hello")

		var iterator = stream.makeAsyncIterator()
		#expect(await iterator.next() == "hello")
	}

	@Test("yield with no awaiting next")
	func yieldWithoutConsumer() {
		_ = AsyncStreamV2<String> { continuation in
			continuation.yield("hello")
		}
	}

	@Test("yield with awaiting next")
	func yieldWithAwaitingNext() async {
		let series = AsyncStreamV2<String> { continuation in
			continuation.yield("hello")
		}
		var iterator = series.makeAsyncIterator()
		#expect(await iterator.next() == "hello")
	}

	@Test("yield with awaiting next 2")
	func yieldTwoValues() async {
		let series = AsyncStreamV2<String> { continuation in
			continuation.yield("hello")
			continuation.yield("world")
		}
		var iterator = series.makeAsyncIterator()
		#expect(await iterator.next() == "hello")
		#expect(await iterator.next() == "world")
	}

	@Test("yield with awaiting next 2 and finish")
	func yieldTwoValuesThenFinish() async {
		let series = AsyncStreamV2<String> { continuation in
			continuation.yield("hello")
			continuation.yield("world")
			continuation.finish()
		}
		var iterator = series.makeAsyncIterator()
		#expect(await iterator.next() == "hello")
		#expect(await iterator.next() == "world")
		#expect(await iterator.next() == nil)
	}

	@Test("yield with no awaiting next detached")
	func yieldDetachedNoConsumer() {
		_ = AsyncStreamV2<String> { continuation in
			Task.detached {
				continuation.yield("hello")
			}
		}
	}

	@Test("yield with awaiting next detached")
	func yieldDetachedWithConsumer() async {
		let series = AsyncStreamV2<String> { continuation in
			Task.detached {
				continuation.yield("hello")
			}
		}
		var iterator = series.makeAsyncIterator()
		#expect(await iterator.next() == "hello")
	}

	@Test("yield with awaiting next 2 detached")
	func yieldTwoValuesDetached() async {
		let series = AsyncStreamV2<String> { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
			}
		}
		var iterator = series.makeAsyncIterator()
		#expect(await iterator.next() == "hello")
		#expect(await iterator.next() == "world")
	}

	@Test("yield with awaiting next 2 and finish detached")
	func yieldTwoValuesFinishDetached() async {
		let series = AsyncStreamV2<String> { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
				continuation.finish()
			}
		}
		var iterator = series.makeAsyncIterator()
		#expect(await iterator.next() == "hello")
		#expect(await iterator.next() == "world")
		#expect(await iterator.next() == nil)
	}

	@Test("yield with awaiting next 2 and finish detached with value after finish")
	func valuesAfterFinishAreIgnored() async {
		let series = AsyncStreamV2<String> { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
				continuation.finish()
				continuation.yield("This should not be emitted")
			}
		}
		var iterator = series.makeAsyncIterator()

		#expect(await iterator.next() == "hello")
		#expect(await iterator.next() == "world")
		#expect(await iterator.next() == nil)
		#expect(await iterator.next() == nil)
	}

	@Test("cancellation behavior on deinit with no values being awaited")
	func cancellationOnDeinit() async {
		func scopedLifetime() {
			_ = AsyncStreamV2<Int> { continuation in
				continuation.onTermination = { terminal in
					#expect(terminal == .cancelled)
				}
			}
		}

		scopedLifetime()
	}

	@Test("onTermination receives .finished when finish() is called")
	func terminationOnDeinitAfterFinishIsFinished() async {
		func scopedLifetime() {
			_ = AsyncStreamV2<Int> { continuation in
				continuation.onTermination = { @Sendable terminal in
					#expect(terminal == .finished)
				}
				continuation.finish()
			}
		}

		scopedLifetime()
	}

	@Test("termination behavior on deinit with finish called")
	func terminationOnDeinitAfterFinish() async {
		func scopedLifetime() {
			_ = AsyncStreamV2<Int> { continuation in
				continuation.onTermination = { _ in
					#expect(Bool(true))
				}
				continuation.finish()
			}
		}

		scopedLifetime()
	}

	
	 @Test("continuation equality")
	 func continuationEquality() {
	 let (_, cont1) = AsyncStreamV2<Int>.makeStream()
	 let (_, cont2) = AsyncStreamV2<Int>.makeStream()

	 #expect(cont1 == cont1)
	 #expect(cont1 != cont2)
	 #expect(cont1.hashValue == cont1.hashValue)
	 #expect(cont1.hashValue != cont2.hashValue)
	 }


	@Test("yield returns terminated after finish")
	func yieldReturnsTerminatedAfterFinish() async {
		let (_, continuation) = AsyncStreamV2<Int>.makeStream()
		continuation.finish()
		let result = continuation.yield(1)
		if case .terminated = result {
			#expect(Bool(true))
		} else {
			Issue.record("expected .terminated, got \(result)")
		}
	}

	@Test("yield returns dropped when buffer is full")
	func yieldReturnsDroppedWhenBufferIsFull() async {
		let (stream, continuation) = AsyncStreamV2<Int>.makeStream(
			bufferingPolicy: .bufferingOldest(2))

		continuation.yield(1)
		continuation.yield(2)
		let result = continuation.yield(3)

		if case let .dropped(value) = result {
			#expect(value == 3)
		} else {
			Issue.record("expected .dropped, got \(result)")
		}

		_ = stream
	}

	@Test("yield returns enqueued with remaining count for bounded buffer")
	func yieldReturnsEnqueuedWithRemainingCount() async {
		let (stream, continuation) = AsyncStreamV2<Int>.makeStream(
			bufferingPolicy: .bufferingNewest(3))

		let r1 = continuation.yield(1)
		let r2 = continuation.yield(2)
		let r3 = continuation.yield(3)

		if case .enqueued(let remaining) = r1 {
			#expect(remaining == 2)
		} else {
			Issue.record("expected .enqueued, got \(r1)")
		}
		if case .enqueued(let remaining) = r2 {
			#expect(remaining == 1)
		} else {
			Issue.record("expected .enqueued, got \(r2)")
		}
		if case .enqueued(let remaining) = r3 {
			#expect(remaining == 0)
		} else {
			Issue.record("expected .enqueued, got \(r3)")
		}

		_ = stream
	}

	@Test("onTermination behavior when canceled")
	func onTerminationBehaviorWhenCanceled() async {
		nonisolated(unsafe) var onTerminationCallCount = 0

		let (stream, continuation) = AsyncStream<String>.makeStream()
		continuation.onTermination = { reason in
			onTerminationCallCount += 1

			switch reason {
			case .cancelled:
				break
			default:
				Issue.record("unexpected termination reason")
			}

			// Yielding or re-entrantly terminating the stream should be ignored
			switch continuation.yield(with: .success("terminated")) {
			case .terminated:
				break;
			default:
				Issue.record("unexpected yield result")
			}

			// Should not re-trigger the callback
			continuation.finish()
		}

		continuation.yield("cancel")

		let results = await Task<[String], Never> {
			var results = [String]()
			for await element in stream {
				results.append(element)
				switch element {
				case "cancel":
					withUnsafeCurrentTask { $0?.cancel() }
				case "terminated":
					Issue.record("should not have yielded '\(element)'")
				default:
					Issue.record("unexpected element")
				}
			}
			return results
		}.value

		#expect(results == ["cancel"])
		#expect(onTerminationCallCount == 1)
	}

	@Test("onTermination behavior when canceled throwing")
	func onTerminationBehaviorWhenCanceledThrowing() async {
		nonisolated(unsafe) var onTerminationCallCount = 0

		let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
		continuation.onTermination = { reason in
			onTerminationCallCount += 1

			switch reason {
			case .cancelled:
				break
			default:
				Issue.record("unexpected termination reason")
			}

			// Yielding or re-entrantly terminating the stream should be ignored
			switch continuation.yield(with: .success("terminated")) {
			case .terminated:
				break;
			default:
				Issue.record("unexpected yield result")
			}

			switch continuation.yield(with: .failure(SomeError())) {
			case .terminated:
				break;
			default:
				Issue.record("unexpected yield result")
			}

			// Should not re-trigger the callback
			continuation.finish()
		}

		continuation.yield("cancel")

		do {
			let results = try await Task<[String], Error> {
				var results = [String]()
				for try await element in stream {
					results.append(element)
					switch element {
					case "cancel":
						withUnsafeCurrentTask { $0?.cancel() }
					case "terminated":
						Issue.record("should not have yielded '\(element)'")
					default:
						Issue.record("unexpected element")
					}
				}
				return results
			}.value

			#expect(results == ["cancel"])
			#expect(onTerminationCallCount == 1)
		} catch {
			Issue.record("unexpected error")
		}
	}
}
