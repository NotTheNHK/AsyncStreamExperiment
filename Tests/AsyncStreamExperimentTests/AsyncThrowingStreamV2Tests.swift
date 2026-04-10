
import Testing
import AsyncStreamExperiment

struct AsyncThrowingStreamV2Tests {
	@Test("throwing factory method")
	func throwingFactoryMethod() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2.makeStream(of: String.self)

		continuation.yield("hello")

		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
	}

	// MARK: - Continuation Identity

	@Test("throwing continuation equality")
	func throwingContinuationEquality() async throws {
		let (_, continuation1) = AsyncThrowingStreamV2<Int, Error>.makeStream()
		let (_, continuation2) = AsyncThrowingStreamV2<Int, Error>.makeStream()

		#expect(continuation1 == continuation1)
		#expect(continuation1 != continuation2)
		#expect(continuation1.hashValue == continuation1.hashValue)
		#expect(continuation1.hashValue != continuation2.hashValue)
	}

	// MARK: - Unfolding Initializer

	@Test("unfolding init: basic throwing")
	func unfoldingBasicThrowing() async throws {
		nonisolated(unsafe) var counter = 0

		let stream = AsyncThrowingStreamV2<Int, Error>(unfolding: {
			counter += 1

			return counter <= 3 ? counter : nil
		})

		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == 1)
		#expect(try await iterator.next(isolation: #isolation) == 2)
		#expect(try await iterator.next(isolation: #isolation) == 3)
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("unfolding init: onCancel called when task is cancelled Throwing")
	func unfoldingOnCancelCalledWhenTaskIsCancelledThrowing() async throws {
		try await confirmation { confirm in
			var counter = 0

			let stream = AsyncThrowingStreamV2(
				unfolding: {
					counter += 1

					if counter == 2 {
						withUnsafeCurrentTask { $0?.cancel() }
					}

					return counter
				},
				onCancel: {
					confirm()
				})

			let iterator = stream.makeAsyncIterator()

			try #expect(await iterator.next(isolation: #isolation) == 1)
			try #expect(await iterator.next(isolation: #isolation) == 2)
			try #expect(await iterator.next(isolation: #isolation) == nil)
		}
	}

	@Test("unfolding init: Throwing")
	func unfoldingThrowing() async throws {
		var counter = 0

		let stream = AsyncThrowingStreamV2<Int, SomeError>(
			unfolding: { () async throws(SomeError) -> Int? in
				counter += 1

				if counter == 3 {
					throw SomeError()
				}

				return counter < 3 ? counter : nil
			},
			onCancel: {})

		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == 1)
		#expect(try await iterator.next(isolation: #isolation) == 2)
		await #expect(throws: SomeError.self) {
			try await iterator.next(isolation: #isolation)
		}
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("unfolding init: onCancel called only once Throwing")
	func unfoldingInitOnCancelCalledOnlyOnceThrowing() async throws {
		try await confirmation { confirm in
			let stream = AsyncThrowingStreamV2<Int, Error>.init(
				unfolding: {
					return nil
				},
				onCancel: {
					confirm()
				})

			withUnsafeCurrentTask { $0?.cancel() }

			let iterator = stream.makeAsyncIterator()

			_ = try await iterator.next(isolation: #isolation)
			_ = try await iterator.next(isolation: #isolation)
			_ = try await iterator.next(isolation: #isolation)
		}
	}

	// MARK: - Yielding

	@Test("yield with no awaiting next throwing")
	func yieldWithNoAwaitingNextThrowing() async throws { // How can we translate this to Swift Testing?
		_ = AsyncThrowingStreamV2(String.self) { continuation in
			continuation.yield("hello")
		}
	}

	@Test("yield with awaiting next throwing")
	func yieldWithAwaitingNextThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self) { continuation in
			continuation.yield("hello")
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
	}

	@Test("yield with awaiting next 2 throwing")
	func yieldWithAwaitingNextTwoThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self) { continuation in
			continuation.yield("hello")
			continuation.yield("world")
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
	}

	// MARK: - Yielding Detached

	@Test("yield with awaiting next detached throwing")
	func yieldWithAwaitingNextDetachedThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self) { continuation in
			Task.detached {
				continuation.yield("hello")
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
	}

	@Test("yield with no awaiting next detached throwing")
	func yieldWithNoAwaitingNextDetachedThrowing() async throws { // How can we translate this to Swift Testing?
		_ = AsyncThrowingStreamV2(String.self) { continuation in
			Task.detached {
				continuation.yield("hello")
			}
		}
	}

	@Test("yield with awaiting next 2 detached throwing")
	func yieldWithAwaitingNextTwoDetachedThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self) { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
	}

	// MARK: - Finishing (Non-Throwing)

	@Test("yield with awaiting next 2 and finish throwing")
	func yieldWithAwaitingNextTwoAndFinishThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self) { continuation in
			continuation.yield("hello")
			continuation.yield("world")
			continuation.finish()
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("yield .terminated after finish throwing")
	func yieldResultTerminatedThrowing() async throws {
		let (stream, cont) = AsyncThrowingStreamV2<String, Error>.makeStream()

		cont.finish(throwing: SomeError())

		if case .terminated = cont.yield("after throw") {
			#expect(true)
		} else {
			Issue.record("expected .terminated for yield after finish(throwing:)")
		}

		_ = stream
	}

	@Test("yield void element throwing")
	func yieldVoidElementThrowing() async throws {
		let (stream, cont) = AsyncThrowingStreamV2<Void, Error>.makeStream()

		if case .enqueued = cont.yield() {
			#expect(true)
		} else {
			Issue.record("expected .enqueued for void yield")
		}

		cont.finish()

		let iterator = stream.makeAsyncIterator()

		try #require(try await iterator.next(isolation: #isolation))
	}

	// MARK: - Finishing With Error

	@Test("yield with awaiting next 2 and finish throwing error")
	func yieldWithAwaitingNextTwoAndThrow() async throws {
		let series = AsyncThrowingStreamV2(String.self, SomeError.self) { continuation in
			continuation.yield("hello")
			continuation.yield("world")
			continuation.finish(throwing: SomeError())
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		await #expect(throws: SomeError.self) {
			try await iterator.next(isolation: #isolation)
		}
	}

	@Test("yield with failure result terminates stream throwing")
	func yieldWithFailureResultTerminatesStreamThrowing() async throws {
		let series = AsyncThrowingStreamV2<String, SomeError> { continuation in
			continuation.yield("before error")

			switch continuation.yield(with: .failure(SomeError())) {
			case .terminated:
				#expect(true)
			default:
				Issue.record("expected .terminated from yield(with: .failure)")
			}

			switch continuation.yield("should not appear") {
			case .terminated:
				#expect(true)
			default:
				Issue.record("expected .terminated after error")
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "before error")
		await #expect(throws: SomeError.self) {
			try await iterator.next(isolation: #isolation)
		}
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("yield with awaiting next 2 and finish with throw after finish throwing")
	func yieldWithAwaitingNextTwoAndFinishWithThrowAfterFinishThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self, SomeError.self) { continuation in
			continuation.yield("hello")
			continuation.yield("world")
			continuation.finish()
			continuation.finish(throwing: SomeError())
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		#expect(try await iterator.next(isolation: #isolation) == nil)
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	// MARK: - Detached Finish

	@Test("yield with awaiting next 2 and finish detached throwing")
	func yieldWithAwaitingNextTwoAndFinishDetachedThrowing() async throws {
		let series = AsyncThrowingStreamV2(String.self) { continuation in
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
		let series = AsyncThrowingStreamV2(String.self, SomeError.self) { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
				continuation.finish(throwing: SomeError())
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
		let series = AsyncThrowingStreamV2(String.self) { continuation in
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
		let series = AsyncThrowingStreamV2(String.self, SomeError.self) { continuation in
			Task.detached {
				continuation.yield("hello")
				continuation.yield("world")
				continuation.finish()
				continuation.finish(throwing: SomeError())
			}
		}

		let iterator = series.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "hello")
		#expect(try await iterator.next(isolation: #isolation) == "world")
		#expect(try await iterator.next(isolation: #isolation) == nil)
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	// MARK: - Iteration Semantics

	@Test("for try await finish")
	func forTryAwait() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2<String, Error>.makeStream()

		continuation.yield("hello")
		continuation.yield("world")
		continuation.finish()

		var collected = [String]()

		for try await element in stream {
			collected.append(element)
		}

		#expect(collected == ["hello", "world"])
	}

	@Test("for try await finish with throwing")
	func forTryAwaitThrowing() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2<String, Error>.makeStream()

		continuation.yield("hello")
		continuation.finish(throwing: SomeError())

		await #expect(throws: SomeError.self) {
			for try await element in stream {
				#expect(element == "hello")
			}
		}
	}

	// MARK: - Cancellation & Termination

	@Test("cancellation behavior on deinit with no values being awaited throwing")
	func cancellationOnDeinit() async {
		await confirmation { confirm in
			func scopedLifetime() {
				_ = AsyncThrowingStreamV2<Int, Error> { continuation in
					continuation.onTermination = { terminal in
						switch terminal {
						case .cancelled:
							confirm()
						case .finished:
							Issue.record("Wrong Termination State")
						}
					}
				}
			}

			scopedLifetime()
		}
	}

	@Test("onTermination receives .finished when finish() is called throwing")
	func terminationOnDeinitAfterFinishIsFinished() async {
		await confirmation { confirm in
			func scopedLifetime() {
				_ = AsyncThrowingStreamV2<Int, Error> { continuation in
					continuation.onTermination = { terminal in
						switch terminal {
						case .finished:
							confirm()
						case .cancelled:
							Issue.record("Wrong Termination State")
						}
					}

					continuation.finish()
				}
			}

			scopedLifetime()
		}
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

	@Test("task cancellation terminates throwing stream")
	func taskCancellationTerminatesThrowingStream() async throws {
		let (stream, _) = AsyncThrowingStreamV2<Int, Error>.makeStream()

		let (controlStream, controlContinuation) = AsyncStreamV2<Void>.makeStream()
		let controlIterator = controlStream.makeAsyncIterator()

		let task = Task { @MainActor in
			let iterator = stream.makeAsyncIterator()

			controlContinuation.yield(Void())

			return try await iterator.next(isolation: #isolation)
		}

		_ = await controlIterator.next(isolation: #isolation)

		await MainActor.run {}

		task.cancel()

		#expect(try await task.value == nil)
	}

	@Test("onTermination throwing finished reasons no error")
	func onTerminationThrowingFinishedReasonsNoError() async throws {
		await confirmation(expectedCount: 0) { confirm in
			let (_, continuation) = AsyncThrowingStreamV2<String, Error>.makeStream()

      continuation.onTermination = { _ in
        confirm()
      }

			continuation.finish()
		}
	}

	@Test("onTermination throwing finished reasons with error")
	func onTerminationThrowingFinishedReasonsWithError() async throws {
		await confirmation(expectedCount: 0) { confirm in
			let (_, continuation) = AsyncThrowingStreamV2<String, SomeError>.makeStream()

      continuation.onTermination = { _ in
        confirm()
      }

			continuation.finish(throwing: SomeError())
		}
	}

	@Test("onTermination after finish throwing")
	func onTerminationAfterFinishThrowing() async throws {
		nonisolated(unsafe) var onTerminationCalled = false

		func scopedLifetime() {
			_ = AsyncThrowingStreamV2(String.self, SomeError.self) { continuation in
				continuation.onTermination = { _ in
					onTerminationCalled = true
				}
				continuation.finish()
			}
		}

		scopedLifetime()

		#expect(onTerminationCalled == true)
	}

	@Test("continuation out of scope cancels stream throwing")
	func continuationOutOfScopeThrowing() async throws {
		try await confirmation { confirm in
			let stream = AsyncThrowingStreamV2<Int, Error> { continuation in
				continuation.onTermination = { terminal in
					switch terminal {
					case .cancelled:
						confirm()
					case .finished:
						Issue.record("Wrong terminal state")
					}
				}
			}

			let iterator = stream.makeAsyncIterator()

			_ = try await iterator.next()
		}
	}

	// MARK: - Multiple Consumers

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

	@Test("error delivered to all waiting consumers throwing") // TODO?: I think only the first consumer should receive the error,
	func errorDeliveredToAllWaitingConsumersThrowing() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2<Int, SomeError>.makeStream()
		let (controlStream, controlContinuation) = AsyncStreamV2<Int>.makeStream()
		let controlIterator = controlStream.makeAsyncIterator()

		func makeConsumingTask(_ index: Int) -> Task<Void, Never> {
			Task { @MainActor in
				controlContinuation.yield(index)
				await #expect(throws: SomeError.self) {
					for try await _ in stream {}
				}
			}
		}

		let consumer1 = makeConsumingTask(1)
		#expect(await controlIterator.next(isolation: #isolation) == 1)

		//let consumer2 = makeConsumingTask(2)
		//#expect(await controlIterator.next(isolation: #isolation) == 2)

		await MainActor.run {}

		continuation.finish(throwing: SomeError())

		_ = await consumer1.value
		//_ = await consumer2.value
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

		await MainActor.run {}

		continuation.yield(10)
		continuation.yield(20)
		continuation.yield(30)
		continuation.yield(40)
		continuation.finish()

		_ = try await consumer1.value
		_ = try await consumer2.value

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

		consumer1.cancel()

		_ = try await consumer1.value
		_ = try await consumer2.value
	}

	// MARK: - Buffering Policy

	@Test("buffering first two, third dropped. Policy: .bufferingOldest")
	func bufferingFirstTwoThirdDroppedPolicyBufferingOldest() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2.makeStream(
			of: Int.self,
			bufferingPolicy: .bufferingOldest(2))

		#expect(continuation.yield(1) == .enqueued(remaining: 1))
		#expect(continuation.yield(2) == .enqueued(remaining: 0))
		#expect(continuation.yield(3) == .dropped(3))

		continuation.finish()
		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == 1)
		#expect(try await iterator.next(isolation: #isolation) == 2)
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("buffering first two, third dropped. Policy: .bufferingNewest")
	func bufferingFirstTwoThirdDroppedPolicyBufferingNewest() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2.makeStream(
			of: Int.self,
			bufferingPolicy: .bufferingNewest(2))

		#expect(continuation.yield(1) == .enqueued(remaining: 1))
		#expect(continuation.yield(2) == .enqueued(remaining: 0))
		#expect(continuation.yield(3) == .dropped(1))

		continuation.finish()
		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == 2)
		#expect(try await iterator.next(isolation: #isolation) == 3)
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("buffering zero capacity drops all. Policy: .bufferingOldest")
	func bufferingZeroCapacityDropsAllPolicyBufferingOldest() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2.makeStream(
			of: Int.self,
			bufferingPolicy: .bufferingOldest(0))

		#expect(continuation.yield(1) == .dropped(1))
		#expect(continuation.yield(2) == .dropped(2))

		continuation.finish()
		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("buffering zero capacity drops all. Policy: .bufferingNewest")
	func bufferingZeroCapacityDropsAllPolicyBufferingNewest() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2.makeStream(
			of: Int.self,
			bufferingPolicy: .bufferingNewest(0))

		#expect(continuation.yield(1) == .dropped(1))
		#expect(continuation.yield(2) == .dropped(2))

		continuation.finish()
		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("buffering negative capacity drops all. Policy: .bufferingOldest")
	func bufferingNegativeCapacityDropsAllPolicybufferingOldest() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2.makeStream(
			of: Int.self,
			bufferingPolicy: .bufferingOldest(-1))

		#expect(continuation.yield(1) == .dropped(1))
		#expect(continuation.yield(2) == .dropped(2))

		continuation.finish()
		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("buffering negative capacity drops all. Policy: .bufferingNewest")
	func bufferingNegativeCapacityDropsAllBufferingNewestPolicy() async throws {
		let (stream, continuation) = AsyncThrowingStreamV2.makeStream(
			of: Int.self,
			bufferingPolicy: .bufferingNewest(-1))

		#expect(continuation.yield(1) == .dropped(1))
		#expect(continuation.yield(2) == .dropped(2))

		continuation.finish()
		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == nil)
	}

	@Test("yield(with:) success throwing")
	func yieldWithAuccessThrowing() async throws {
		let (stream, cont) = AsyncThrowingStreamV2<String, Error>.makeStream()

		cont.yield(with: .success("world"))
		cont.finish()

		let iterator = stream.makeAsyncIterator()

		#expect(try await iterator.next(isolation: #isolation) == "world")
		#expect(try await iterator.next(isolation: #isolation) == nil)
	}
}
