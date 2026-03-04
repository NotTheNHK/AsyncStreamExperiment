import Testing
@testable import AsyncStreamExperiment

struct AsyncStreamV2Tests {
	@Test("factory method")
	func factoryMethod() async {
		let (stream, continuation) = AsyncStreamV2<String>.makeStream()
		continuation.yield("hello")

		var iterator = stream.makeAsyncIterator()
		#expect(await iterator.next() == "hello")
	}

	// MARK: - Continuation Identity

	@Test("continuation equality")
	func continuationEquality() {
		let (_, cont1) = AsyncStreamV2<Int>.makeStream()
		let (_, cont2) = AsyncStreamV2<Int>.makeStream()

		#expect(cont1 == cont1)
		#expect(cont1 != cont2)
		#expect(cont1.hashValue == cont1.hashValue)
		#expect(cont1.hashValue != cont2.hashValue)
	}

	// MARK: - Yielding

	@Test("yield with no awaiting next")
	func yieldWithoutConsumer() { // How can we translate this to Swift Testing?
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

	// MARK: - Detached Yielding

	@Test("yield with no awaiting next detached")
	func yieldDetachedNoConsumer() { // How can we translate this to Swift Testing?
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

	// MARK: - Yield Result Semantics

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

	@Test("yield result enqueued remaining unbounded")
	func yieldResultEnqueuedRemainingUnbounded() async throws {
		let (stream, cont) = AsyncStreamV2<String>.makeStream()

		if case let .enqueued(remaining) = cont.yield("hello") {
			#expect(remaining == Int.max)
		} else {
			Issue.record("expected .enqueued(Int.max) for unbounded stream")
		}

		_ = stream
	}

	@Test("yield result enqueued remaining bounded")
	func yieldResultEnqueuedRemainingBounded() async throws {
		let (stream, cont) = AsyncStreamV2.makeStream(
			of: String.self,
			bufferingPolicy: .bufferingOldest(3))

		let r1 = cont.yield("a")
		let r2 = cont.yield("b")
		let r3 = cont.yield("c")
		let r4 = cont.yield("d")

		if case let .enqueued(r1) = r1 { #expect(r1 == 2) }
		else { Issue.record("expected .enqueued(2) for b1") }
		if case let .enqueued(r2) = r2 { #expect(r2 == 1) }
		else { Issue.record("expected .enqueued(1) for b2") }
		if case let .enqueued(r3) = r3 { #expect(r3 == 0) }
		else { Issue.record("expected .enqueued(0) for b3") }
		if case .dropped = r4 { #expect(true) }
		else { Issue.record("expected .dropped for b4 when buffer full") }

		_ = stream
	}

	@Test("yield .terminated after finish")
	func yieldResultTerminated() async throws {
		let (stream, cont) = AsyncStreamV2<String>.makeStream()

		cont.finish()

		if case .terminated = cont.yield("after finish") {
			#expect(true)
		} else {
			Issue.record("expected .terminated for yield after finish")
		}

		_ = stream
	}

	@Test("yield(with:) success")
	func yieldWithSuccess() async throws {
		let (stream, cont) = AsyncStreamV2<String>.makeStream()

		cont.yield(with: .success("hello"))
		cont.finish()

		let iterator = stream.makeAsyncIterator()

		#expect(await iterator.next(isolation: #isolation) == "hello")
		#expect(await iterator.next(isolation: #isolation) == nil)
	}

	@Test("yield void element")
	func yieldVoidElement() async throws {
		let (stream, cont) = AsyncStreamV2<Void>.makeStream()

		if case .enqueued = cont.yield() {
			#expect(true)
		} else {
			Issue.record("expected .enqueued for void yield")
		}

		cont.finish()

		let iterator = stream.makeAsyncIterator()

		try #require(await iterator.next(isolation: #isolation))
	}

	// MARK: - Buffering Policies

	@Test("bufferingOldest semantics")
	func bufferingOldestSemantics() async throws {
		let (stream, continuation) = AsyncStreamV2<String>.makeStream(
			bufferingPolicy: .bufferingOldest(3))

		let r1 = continuation.yield("a")
		let r2 = continuation.yield("b")
		let r3 = continuation.yield("c") // buffer now full
		let r4 = continuation.yield("d") // should be dropped
		let r5 = continuation.yield("e") // should be dropped
		continuation.finish()

		if case .enqueued(let remaining) = r1 { #expect(remaining == 2) }
		else { Issue.record("expected .enqueued(2) for r1") }
		if case .enqueued(let remaining) = r2 { #expect(remaining == 1) }
		else { Issue.record("expected .enqueued(1) for r2") }
		if case .enqueued(let remaining) = r3 { #expect(remaining == 0) }
		else { Issue.record("expected .enqueued(0) for r3") }
		if case .dropped(let value) = r4 { #expect(value == "d") }
		else { Issue.record("expected .dropped(d) for r4") }
		if case .dropped(let value) = r5 { #expect(value == "e") }
		else { Issue.record("expected .dropped(e) for r5") }

		let iterator = stream.makeAsyncIterator()
		#expect(await iterator.next(isolation: #isolation) == "a")
		#expect(await iterator.next(isolation: #isolation) == "b")
		#expect(await iterator.next(isolation: #isolation) == "c")
		#expect(await iterator.next(isolation: #isolation) == nil)
	}

	@Test("bufferingNewest semantics")
	func bufferingNewestSemantics() async throws {
		let (stream, continuation) = AsyncStreamV2.makeStream(
			of: String.self,
			bufferingPolicy: .bufferingNewest(3))

		let r1 = continuation.yield("a")
		let r2 = continuation.yield("b")
		let r3 = continuation.yield("c")
		let r4 = continuation.yield("d") // full: evicts oldest "a"
		let r5 = continuation.yield("e") // full: evicts oldest "b"
		continuation.finish()

		if case .enqueued(let remaining) = r1 { #expect(remaining == 2) }
		else { Issue.record("expected .enqueued(2) for r1") }
		if case .enqueued(let remaining) = r2 { #expect(remaining == 1) }
		else { Issue.record("expected .enqueued(1) for r2") }
		if case .enqueued(let remaining) = r3 { #expect(remaining == 0) }
		else { Issue.record("expected .enqueued(0) for r3") }
		// The dropped value is the evicted oldest, not the incoming element
		if case .dropped(let value) = r4 { #expect(value == "a") }
		else { Issue.record("expected .dropped(a) for r4") }
		if case .dropped(let value) = r5 { #expect(value == "b") }
		else { Issue.record("expected .dropped(b) for r5") }

		let iterator = stream.makeAsyncIterator()
		#expect(await iterator.next(isolation: #isolation) == "c")
		#expect(await iterator.next(isolation: #isolation) == "d")
		#expect(await iterator.next(isolation: #isolation) == "e")
		#expect(await iterator.next(isolation: #isolation) == nil)
	}

	@Test("buffering zero capacity drops all")
	func bufferingZeroCapacityDropsAll() async {
		// bufferingOldest(0): every yield dropped immediately
		let (oldestStream, oldestCont) = AsyncStreamV2<Int>.makeStream(
			bufferingPolicy: .bufferingOldest(0)
		)
		if case .dropped(let v) = oldestCont.yield(1) { #expect(v == 1) }
		else { Issue.record("expected .dropped(1) for bufferingOldest(0)") }
		if case .dropped(let v) = oldestCont.yield(2) { #expect(v == 2) }
		else { Issue.record("expected .dropped(2) for bufferingOldest(0)") }
		oldestCont.finish()
		let oldestIt = oldestStream.makeAsyncIterator()

		#expect(await oldestIt.next(isolation: #isolation) == nil)

		// bufferingNewest(0): every yield dropped immediately
		let (newestStream, newestCont) = AsyncStreamV2.makeStream(
			of: Int.self,
			bufferingPolicy: .bufferingNewest(0)
		)
		if case .dropped(let v) = newestCont.yield(3) { #expect(v == 3) }
		else { Issue.record("expected .dropped(3) for bufferingNewest(0)") }
		if case .dropped(let v) = newestCont.yield(4) { #expect(v == 4) }
		else { Issue.record("expected .dropped(4) for bufferingNewest(0)") }
		newestCont.finish()
		let newestIt = newestStream.makeAsyncIterator()
		#expect(await newestIt.next(isolation: #isolation) == nil)
	}

	@Test("buffering negative capacity drops all")
	func bufferingNegativeCapacityDropsAll() async throws {
		let (oldestStream, oldestCont) = AsyncStreamV2<Int>.makeStream(
			bufferingPolicy: .bufferingOldest(-1)
		)
		if case .dropped(let v) = oldestCont.yield(1) { #expect(v == 1) }
		else { Issue.record("expected .dropped(1) for bufferingOldest(0)") }
		if case .dropped(let v) = oldestCont.yield(2) { #expect(v == 2) }
		else { Issue.record("expected .dropped(2) for bufferingOldest(0)") }
		oldestCont.finish()
		let oldestIt = oldestStream.makeAsyncIterator()
		#expect(await oldestIt.next(isolation: #isolation) == nil)

		// bufferingNewest(-1): every yield dropped immediately
		let (newestStream, newestCont) = AsyncStreamV2.makeStream(
			of: Int.self,
			bufferingPolicy: .bufferingNewest(-1)
		)
		if case .dropped(let v) = newestCont.yield(3) { #expect(v == 3) }
		else { Issue.record("expected .dropped(3) for bufferingNewest(0)") }
		if case .dropped(let v) = newestCont.yield(4) { #expect(v == 4) }
		else { Issue.record("expected .dropped(4) for bufferingNewest(0)") }
		newestCont.finish()
		let newestIt = newestStream.makeAsyncIterator()
		#expect(await newestIt.next(isolation: #isolation) == nil)
	}


	// MARK: - Finish & Idempotence

	@Test("finish idempotence non throwing")
	func finishIdempotenceNonThrowing() async throws {
		let series = AsyncStreamV2(String.self) { continuation in
			nonisolated(unsafe) var terminalCallCount = 0

			continuation.onTermination = { _ in terminalCallCount += 1 }

			continuation.yield("hello")

			continuation.finish()
			#expect(terminalCallCount == 1)

			continuation.finish()
			#expect(terminalCallCount == 1)
		}

		let iterator = series.makeAsyncIterator()

		#expect(await iterator.next(isolation: #isolation) == "hello")
		#expect(await iterator.next(isolation: #isolation) == nil)
		#expect(await iterator.next(isolation: #isolation) == nil)
	}

	@Test("onTermination finished reason")
	func onTerminationFinishedReason() async throws {
		let (_, continuation) = AsyncStreamV2<String>.makeStream()

		continuation.onTermination = { terminal in
			#expect(terminal == .finished)
		}

		continuation.finish()
	}

	@Test("onTermination receives .finished when finish() is called")
	func terminationOnDeinitAfterFinishIsFinished() async {
		func scopedLifetime() {
			_ = AsyncStreamV2<Int> { continuation in
				continuation.onTermination = { terminal in
					#expect(terminal == .finished)
				}
				continuation.finish()
			}
		}

		scopedLifetime()
	}

	@Test("onTermination called exactly once")
	func onTerminationThrowingFinishedReasons() async throws {
		nonisolated(unsafe) var counter = 0
		let (_, continuation) = AsyncStreamV2<String>.makeStream()

		continuation.onTermination = { _ in counter += 1 }
		continuation.finish()

		continuation.onTermination = { _ in counter += 1 }
		continuation.finish()

		#expect(counter == 1)
	}

	// MARK: - Termination & Cancellation

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

	@Test("onTermination behavior when canceled")
	func onTerminationBehaviorWhenCanceled() async {
		nonisolated(unsafe) var onTerminationCallCount = 0

		let (stream, continuation) = AsyncStreamV2<String>.makeStream()
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

	@Test("task cancellation terminates stream")
	func taskCancellationTerminatesStream() async throws {
		let (stream, continuation) = AsyncStreamV2<Int>.makeStream()
		continuation.onTermination = { terminal in
			#expect(terminal == .cancelled)
		}

		let (controlStream, controlContinuation) = AsyncStreamV2<Void>.makeStream()
		let controlIterator = controlStream.makeAsyncIterator()

		let task = Task { @MainActor in
			let iterator = stream.makeAsyncIterator()

			controlContinuation.yield(Void())

			return await iterator.next(isolation: #isolation)
		}

		_ = await controlIterator.next(isolation: #isolation)

		await MainActor.run {}

		#expect(continuation.onTermination != nil)
		task.cancel()
		#expect(continuation.onTermination == nil)

		#expect(await task.value == nil)
	}

	// MARK: - Multiple Consumers

	@Test("finish behavior with multiple consumers")
	func finishBehaviorWithMultipleConsumers() async throws {
		let (stream, continuation) = AsyncStreamV2<Int>.makeStream()
		let (controlStream, controlContinuation) = AsyncStreamV2<Int>.makeStream()
		let controlIterator = controlStream.makeAsyncIterator()

		func makeConsumingTaskWithIndex(_ index: Int) -> Task<Void, Never> {
			Task { @MainActor in
				controlContinuation.yield(index)
				for await i in stream {
					controlContinuation.yield(i)
				}
			}
		}

		let consumer1 = makeConsumingTaskWithIndex(1)
		#expect(await controlIterator.next(isolation: #isolation) == 1)

		let consumer2 = makeConsumingTaskWithIndex(2)
		#expect(await controlIterator.next(isolation: #isolation) == 2)

		await MainActor.run {}

		continuation.finish()

		_ = await consumer1.value
		_ = await consumer2.value
	}

	@Test("element delivery with multiple consumers")
	func elementDeliveryWithMultipleConsumers() async throws {
		final class Collector: @unchecked Sendable {
			var received: [Int] = []
		}
		let collector = Collector()
		let (stream, continuation) = AsyncStreamV2<Int>.makeStream()
		let (controlStream, controlContinuation) = AsyncStreamV2<Int>.makeStream()
		let controlIterator = controlStream.makeAsyncIterator()

		let consumer1 = Task { @MainActor in
			controlContinuation.yield(1)
			for await value in stream {
				collector.received.append(value)
			}
		}
		#expect(await controlIterator.next(isolation: #isolation) == 1)

		let consumer2 = Task { @MainActor in
			controlContinuation.yield(2)
			for await value in stream {
				collector.received.append(value)
			}
		}
		#expect(await controlIterator.next(isolation: #isolation) == 2)

		await MainActor.run {}

		continuation.yield(10)
		continuation.yield(20)
		continuation.yield(30)
		continuation.yield(40)
		continuation.finish()

		_ = await consumer1.value
		_ = await consumer2.value

		#expect(collector.received.sorted() == [10, 20, 30, 40])
	}

	@Test("cancellation of one consumer terminates the stream for all consumers")
	func cancellationOfOneConsumerTerminatesTheStreamForAllConsumers() async throws {
		let (stream, _) = AsyncStreamV2<Int>.makeStream()
		let (controlStream, controlContinuation) = AsyncStreamV2<Int>.makeStream()
		let controlIterator = controlStream.makeAsyncIterator()

		let consumer1 = Task { @MainActor in
			controlContinuation.yield(1)
			for await _ in stream {}
		}
		#expect(await controlIterator.next(isolation: #isolation) == 1)

		let consumer2 = Task { @MainActor in
			controlContinuation.yield(2)
			for await _ in stream {}
		}
		#expect(await controlIterator.next(isolation: #isolation) == 2)

		await MainActor.run {}

		consumer1.cancel()

		_ = await consumer1.value
		_ = await consumer2.value
	}
}
