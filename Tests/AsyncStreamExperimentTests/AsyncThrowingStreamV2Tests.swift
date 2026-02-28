import Testing
@testable import AsyncStreamExperiment

struct AsyncThrowingStreamV2Tests {
	@Test("throwing factory method")
	func throwingFactoryMethod() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2.makeStream(of: String.self, throwing: Error.self)

		continuation.yield("hello")

		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
	}

	@Test("yield with no awaiting next throwing")
	func yieldWithNoAwaitingNextThrowing() async throws {
		_ = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			continuation.yield("hello")
		}
	}

	@Test("yield with awaiting next throwing")
	func yieldWithAwaitingNextThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			continuation.yield("hello")
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
	}

	@Test("yield with awaiting next 2 throwing")
	func yieldWithAwaitingNextTwoThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			continuation.yield("hello")
			continuation.yield("world")
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
	}

	@Test("yield with awaiting next 2 and finish throwing")
	func yieldWithAwaitingNextTwoAndFinishThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			continuation.yield("hello")
			continuation.yield("world")
			continuation.finish()
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("yield with awaiting next 2 and throw")
	func yieldWithAwaitingNextTwoAndThrow() async throws {
		let thrownError = SomeError()

		let series = AsyncThrowingStreamV2(String.self, SomeError.self) { continuation in
			continuation.yield("hello")
			continuation.yield("world")
			continuation.finish(throwing: thrownError)
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		await #expect(throws: SomeError.self) {
			try await iterator.next(isolation: #isolation)
		}
	}

	@Test("yield with no awaiting next detached throwing")
	func yieldWithNoAwaitingNextDetachedThrowing() async throws {
		_ = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			Task.detached {
				continuation.yield("hello")
			}
		}
	}

	@Test("yield with awaiting next detached throwing")
	func yieldWithAwaitingNextDetachedThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			Task.detached {
				continuation.yield("hello")
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
	}

	@Test("yield with awaiting next 2 detached throwing")
	func yieldWithAwaitingNextTwoDetachedThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
	}

	@Test("yield with awaiting next 2 and finish detached throwing")
	func yieldWithAwaitingNextTwoAndFinishDetachedThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
				continuation.finish()
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("yield with awaiting next 2 and throw detached")
	func yieldWithAwaitingNextTwoAndThrowDetached() async throws {
		let thrownError = SomeError()

		let series = AsyncThrowingStreamV2(String.self, SomeError.self) { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
				continuation.finish(throwing: thrownError)
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		await #expect(throws: SomeError.self) {
			try await iterator.next(isolation: #isolation)
		}
	}

	@Test("yield with awaiting next 2 and finish detached with value after finish throwing")
	func yieldWithAwaitingNextTwoAndFinishDetachedWithValueAfterFinishThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
				continuation.finish()
				continuation.yield("This should not be emitted")
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		#expect(try await iterator.next(isolation: #isolation) == nil)
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("yield with awaiting next 2 and finish detached with throw after finish throwing")
	func yieldWithAwaitingNextTwoAndFinishDetachedWithThrowAfterFinishThrowing() async throws {
		let thrownError = SomeError()

		let series = AsyncThrowingStreamV2(String.self, SomeError.self) { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
				continuation.finish()
				continuation.finish(throwing: thrownError)
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		#expect(try await iterator.next(isolation: #isolation) == nil)
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("yield with awaiting next 2 and finish with throw after finish throwing")
	func yieldWithAwaitingNextTwoAndFinishWithThrowAfterFinishThrowing() async throws {
		let thrownError = SomeError()

		let series = AsyncThrowingStreamV2(String.self, SomeError.self) { continuation in
			continuation.yield("hello")
			continuation.yield("world")
			continuation.finish()
			continuation.finish(throwing: thrownError)
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		#expect(try await iterator.next(isolation: #isolation) == nil)
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("cancellation behavior on deinit with no values being awaited throwing")
	func cancellationBehaviorOnDeinitWithNoValuesBeingAwaitedThrowing() async throws {
		func scopedLifetime() {
			_ = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
				continuation.onTermination = { terminal in
					switch terminal {
					case .finished:
						Issue.record("Wrong Termination State")
					case .cancelled:
						#expect(Bool(true))
					}
				}
			}
		}

		scopedLifetime()
	}

	@Test("throwing continuation equality")
	func throwingContinuationEquality() async throws {
		let (_, continuation1) = AsyncThrowingStream<Int, Error>.makeStream()
		let (_, continuation2) = AsyncThrowingStream<Int, Error>.makeStream()

		#expect(continuation1 == continuation1)
		#expect(continuation1 != continuation2)
		#expect(continuation1.hashValue == continuation1.hashValue)
		#expect(continuation1.hashValue != continuation2.hashValue)
	}

	@Test("finish behavior with multiple consumers")
	func finishBehaviorWithMultipleConsumers() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2<Int, Error>.makeStream()
		let (controlStream, controlContinuation) = AsyncThrowingStreamV2<Int, Error>.makeStream()
		let controlIterator = controlStream.makeAsyncIterator()

		func makeConsumingTaskWithIndex(_ index: Int) -> Task<Void, Error> {
			Task { @MainActor in
				controlContinuation.yield(index)
				for try await i in stream {
					controlContinuation.yield(i)
				}
			}
		}

		let consumer1 = makeConsumingTaskWithIndex(1)
		#expect(try await controlIterator.next(isolation: #isolation) == 1)

		let consumer2 = makeConsumingTaskWithIndex(2)
		#expect(try await controlIterator.next(isolation: #isolation) == 2)

		await MainActor.run {}

		continuation.finish()

		_ = try await consumer1.value
		_ = try await consumer2.value
	}

	@Test("onTermination behavior when canceled throwing")
	func onTerminationBehaviorWhenCanceledThrowing() async throws {
		nonisolated(unsafe) var onTerminationCallCount = 0

		let (stream, continuation) = AsyncThrowingStreamV2<String, Error>.makeStream()
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

	@Test("error delivered to all waiting consumers throwing")
	func errorDeliveredToAllWaitingConsumersThrowing() async throws {
		let thrownError = SomeError()
		final class Collector: @unchecked Sendable {
			var errorCount = 0
		}
		let collector = Collector()
		let (stream, continuation) = AsyncThrowingStreamV2<Int, Error>.makeStream()
		let (controlStream, controlContinuation) = AsyncStream<Int>.makeStream()
		var controlIterator = controlStream.makeAsyncIterator()

		func makeConsumingTask(_ index: Int) -> Task<Void, Never> {
			Task { @MainActor in
				controlContinuation.yield(index)
				do {
					for try await _ in stream {}
				} catch let error as SomeError {
					#expect(error == thrownError)
					collector.errorCount += 1
				} catch {
					Issue.record("unexpected error type: \(error)")
				}
			}
		}

		let consumer1 = makeConsumingTask(1)
		#expect(await controlIterator.next(isolation: #isolation) == 1)

		let consumer2 = makeConsumingTask(2)
		#expect(await controlIterator.next(isolation: #isolation) == 2)

		await MainActor.run {}

		continuation.finish(throwing: thrownError)

		_ = await consumer1.value
		_ = await consumer2.value

		#expect(collector.errorCount == 2)
	}

	@Test("element delivery with multiple consumers")
	func elementDeliveryWithMultipleConsumers() async throws {
		final class Collector: @unchecked Sendable {
			var received: [Int] = []
		}
		let collector = Collector()
		let (stream, continuation) = AsyncThrowingStreamV2<Int, Error>.makeStream()
		let (controlStream, controlContinuation) = AsyncThrowingStreamV2<Int, Error>.makeStream()
		let controlIterator = controlStream.makeAsyncIterator()

		let consumer1 = Task { @MainActor in
			controlContinuation.yield(1)
			for try await value in stream {
				collector.received.append(value)
			}
		}
		#expect(try await controlIterator.next(isolation: #isolation) == 1)

		let consumer2 = Task { @MainActor in
			controlContinuation.yield(2)
			for try await value in stream {
				collector.received.append(value)
			}
		}
		#expect(try await controlIterator.next(isolation: #isolation) == 2)

		// Ensure both consumers are suspended in next()
		await MainActor.run {}

		continuation.yield(10)
		continuation.yield(20)
		continuation.yield(30)
		continuation.yield(40)
		continuation.finish()

		_ = try await consumer1.value
		_ = try await consumer2.value

		// Each element should be delivered to exactly one consumer — none lost or duplicated
		#expect(collector.received.sorted() == [10, 20, 30, 40])
	}

	@Test("cancellation of one consumer terminates the stream for all consumers")
	func cancellationOfOneConsumerTerminatesTheStreamForAllConsumers() async throws {
		let (stream, _) = AsyncThrowingStreamV2<Int, Error>.makeStream()
		let (controlStream, controlContinuation) = AsyncThrowingStreamV2<Int, Error>.makeStream()
		let controlIterator = controlStream.makeAsyncIterator()

		let consumer1 = Task { @MainActor in
			controlContinuation.yield(1)
			for try await _ in stream {}
		}
		#expect(try await controlIterator.next(isolation: #isolation) == 1)

		let consumer2 = Task { @MainActor in
			controlContinuation.yield(2)
			for try await _ in stream {}
		}
		#expect(try await controlIterator.next(isolation: #isolation) == 2)

		await MainActor.run {}

		// Cancelling consumer1 triggers storage.cancel(), terminating the stream
		// and resuming all waiting continuations — including consumer2's
		consumer1.cancel()

		_ = try await consumer1.value
		_ = try await consumer2.value
	}
}
