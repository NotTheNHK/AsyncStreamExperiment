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

	// MARK: - Yielding

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

	// MARK: - Yielding Detached

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

	@Test("yield with no awaiting next detached throwing")
	func yieldWithNoAwaitingNextDetachedThrowing() async throws {
		_ = AsyncThrowingStreamV2(String.self, Error.self) { continuation in
			Task.detached {
				continuation.yield("hello")
			}
		}
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

	// MARK: - Finishing (Non-Throwing)

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

			if case .terminated = continuation.yield(with: .failure(SomeError())) {
				#expect(true)
			} else {
				Issue.record("expected .terminated from yield(with: .failure)")
			}

			if case .terminated = continuation.yield("should not appear") {
				#expect(true)
			} else {
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

	// MARK: - Detached Finish

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
		func scopedLifetime() {
			_ = AsyncThrowingStreamV2<Int, Error> { continuation in
				continuation.onTermination = { terminal in
					switch terminal {
					case .cancelled:
						#expect(true)
					case .finished:
						Issue.record("Wrong Termination State")
					}
				}
			}
		}

		scopedLifetime()
	}

	@Test("onTermination receives .finished when finish() is called throwing")
	func terminationOnDeinitAfterFinishIsFinished() async {
		func scopedLifetime() {
			_ = AsyncThrowingStreamV2<Int, Error> { continuation in
				continuation.onTermination = { terminal in
					switch terminal {
					case .finished:
						#expect(true)
					case .cancelled:
						Issue.record("Wrong Termination State")
					}
				}
				continuation.finish()
			}
		}

		scopedLifetime()
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
		let (_, continuation) = AsyncThrowingStreamV2<String, Error>.makeStream()

		continuation.onTermination = { terminal in
			switch terminal {
			case let .finished(failure):
				#expect(failure == nil)
			case .cancelled:
				Issue.record("Wrong terminal state")
			}
		}

		continuation.finish()
	}

	@Test("onTermination throwing finished reasons with error")
	func onTerminationThrowingFinishedReasonsWithError() async throws {
		let (_, continuation) = AsyncThrowingStreamV2<String, SomeError>.makeStream()

		continuation.onTermination = { terminal in
			switch terminal {
			case let .finished(failure):
				#expect(failure != nil)
			case .cancelled:
				Issue.record("Wrong terminal state")
			}
		}

		continuation.finish(throwing: SomeError())
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

	@Test("buffering policy semantics throwing")
	func bufferingPolicySemanticsThrowing() async throws {
		// bufferingOldest(2): first two kept, third dropped (incoming is dropped)
		let (oldestStream, oldestCont) = AsyncThrowingStreamV2<String, Error>.makeStream(
			bufferingPolicy: .bufferingOldest(2))

		_ = oldestCont.yield("a")
		_ = oldestCont.yield("b")
		let oldestDropped = oldestCont.yield("c")

		if case .dropped(let value) = oldestDropped { #expect(value == "c") }
		else { Issue.record("expected .dropped(c) for oldest overflow") }

		oldestCont.finish()

		do {
			let oldestIt = oldestStream.makeAsyncIterator()
			#expect(try await oldestIt.next(isolation: #isolation) == "a")
			#expect(try await oldestIt.next(isolation: #isolation) == "b")
			#expect(try await oldestIt.next(isolation: #isolation) == nil)
		} catch {
			Issue.record("unexpected error in bufferingOldest throwing test")
		}

		// bufferingNewest(2): oldest evicted when full, newest kept
		let (newestStream, newestCont) = AsyncThrowingStreamV2<String, Error>.makeStream(
			bufferingPolicy: .bufferingNewest(2))

		_ = newestCont.yield("x")
		_ = newestCont.yield("y")
		let newestDropped = newestCont.yield("z")

		if case .dropped(let value) = newestDropped { #expect(value == "x") }
		else { Issue.record("expected .dropped(x) eviction for newest overflow") }

		newestCont.finish()

		do {
			let newestIt = newestStream.makeAsyncIterator()
			#expect(try await newestIt.next(isolation: #isolation) == "y")
			#expect(try await newestIt.next(isolation: #isolation) == "z")
			#expect(try await newestIt.next(isolation: #isolation) == nil)
		} catch {
			Issue.record("unexpected error in bufferingNewest throwing test")
		}
	}

	@Test("buffering zero capacity drops all")
	func bufferingZeroCapacityDropsAll() async throws {
		// bufferingOldest(0): every yield dropped immediately
		let (oldestStream, oldestCont) = AsyncThrowingStreamV2<Int, Error>.makeStream(
			bufferingPolicy: .bufferingOldest(0)
		)
		if case .dropped(let v) = oldestCont.yield(1) { #expect(v == 1) }
		else { Issue.record("expected .dropped(1) for bufferingOldest(0)") }
		if case .dropped(let v) = oldestCont.yield(2) { #expect(v == 2) }
		else { Issue.record("expected .dropped(2) for bufferingOldest(0)") }
		oldestCont.finish()
		let oldestIt = oldestStream.makeAsyncIterator()
		#expect(try await oldestIt.next(isolation: #isolation) == nil)

		// bufferingNewest(0): every yield dropped immediately
		let (newestStream, newestCont) = AsyncThrowingStreamV2.makeStream(
			of: Int.self,
			throwing: Error.self,
			bufferingPolicy: .bufferingNewest(0)
		)
		if case .dropped(let v) = newestCont.yield(3) { #expect(v == 3) }
		else { Issue.record("expected .dropped(3) for bufferingNewest(0)") }
		if case .dropped(let v) = newestCont.yield(4) { #expect(v == 4) }
		else { Issue.record("expected .dropped(4) for bufferingNewest(0)") }
		newestCont.finish()
		let newestIt = newestStream.makeAsyncIterator()
		#expect(try await newestIt.next(isolation: #isolation) == nil)
	}

	@Test("buffering negative capacity drops all")
	func bufferingNegativeCapacityDropsAll() async throws {
		// bufferingOldest(-1): every yield dropped immediately
		let (oldestStream, oldestCont) = AsyncThrowingStreamV2<Int, Error>.makeStream(
			bufferingPolicy: .bufferingOldest(-1)
		)
		if case .dropped(let v) = oldestCont.yield(1) { #expect(v == 1) }
		else { Issue.record("expected .dropped(1) for bufferingOldest(0)") }
		if case .dropped(let v) = oldestCont.yield(2) { #expect(v == 2) }
		else { Issue.record("expected .dropped(2) for bufferingOldest(0)") }
		oldestCont.finish()
		let oldestIt = oldestStream.makeAsyncIterator()
		#expect(try await oldestIt.next(isolation: #isolation) == nil)

		// bufferingNewest(-1): every yield dropped immediately
		let (newestStream, newestCont) = AsyncThrowingStreamV2.makeStream(
			of: Int.self,
			throwing: Error.self,
			bufferingPolicy: .bufferingNewest(-1)
		)
		if case .dropped(let v) = newestCont.yield(3) { #expect(v == 3) }
		else { Issue.record("expected .dropped(3) for bufferingNewest(0)") }
		if case .dropped(let v) = newestCont.yield(4) { #expect(v == 4) }
		else { Issue.record("expected .dropped(4) for bufferingNewest(0)") }
		newestCont.finish()
		let newestIt = newestStream.makeAsyncIterator()
		#expect(try await newestIt.next(isolation: #isolation) == nil)
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
