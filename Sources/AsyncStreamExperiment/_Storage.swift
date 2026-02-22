//
// _Storage.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/11/26 at 11:51 PM
//

import Collections

final class _Storage<Element, Failure: Error>: @unchecked Sendable {
	typealias Consumer = CheckedContinuation<Result<Element?, Failure>, Never>
	typealias Continuation = AsyncStreamExperiment.Continuation<Element, Failure>
	typealias TerminationHandler = @Sendable (Continuation.Termination) -> Void

	enum State { // TODO?: Add 'draining' case?
		case active

		case terminated
	}

	enum BufferState {
		case empty

		case occupied
	}

	enum ConsumerState {
		case disconnected

		case connected
	}

	enum YieldAction {
		case resume(
			yieldResult: Continuation.YieldResult,
			consumer: Optional<Consumer>,
			element: Optional<Element>)

		case none(
			yieldResult: Continuation.YieldResult)
	}

	enum NextAction {
		case resume(element: Element?)

		case suspend

		case failConcurrentAccess
	}

	private let lock = Lock.createLock()
	private var state = State.active

	private var consumer: Consumer?
	private var buffer = Deque<Element>()
	private var bufferPolicy: Continuation.BufferingPolicy
	private var onTermination: TerminationHandler?

	init(bufferPolicy: Continuation.BufferingPolicy) {
		self.bufferPolicy = bufferPolicy
	}

	deinit {
		self.terminate(.cancelled)
		Lock.destructLock(self.lock)
	}
}

extension _Storage {
	var consumerState: ConsumerState { // TODO?: Refactor state machine to single enum?
		self.consumer == nil ? .disconnected : .connected
	}

	var bufferState: BufferState { // TODO?: Refactor state machine to single enum?
		self.buffer.isEmpty ? .empty : .occupied
	}
}

extension _Storage {
	func getOnTermination() -> TerminationHandler? {
		self.lock.whileLocked {
			return self.onTermination
		}
	}

	func setOnTermination(_ newValue: TerminationHandler?) {
		self.lock.whileLocked {
			self.onTermination = newValue
		}
	}

	@Sendable func terminate(_ terminationReason: Continuation.Termination) {
		let terminationHandler = self.lock.whileLocked {
			switch self.state {
			case .active:
				self.state = .terminated

				return self.onTermination.take()
			case .terminated:
				return nil
			}
		}

		terminationHandler?(terminationReason)
	}

	func yield(_ value: sending Element) -> Continuation.YieldResult {
		let action: YieldAction = self.lock.whileLocked {
			let consumerState = self.consumerState // TODO?: Currently, we need to snapshot here
			let bufferState = self.bufferState // TODO?: Currently, we need to snapshot here

			let consumer = self.consumer.take()
			let result: Continuation.YieldResult
			let count = self.buffer.count
			let remainingCount = { (limit: Int) -> Int in
				limit - (count + 1)
			}

			switch self.state {
			case .active:
				switch (consumerState, bufferState) {
				case (.connected, .empty):
					switch self.bufferPolicy {
					case .unbounded:
						result = .enqueued(remaining: .max)
					case let .bufferingOldest(limit), let .bufferingNewest(limit):
						result = .enqueued(remaining: limit)
					}

					return .resume(yieldResult: result, consumer: consumer, element: value)
				case (.connected, .occupied):
					switch self.bufferPolicy {
					case .unbounded:
						result = .enqueued(remaining: .max)
						self.buffer.append(value)
					case let .bufferingOldest(limit):
						switch count < limit {
						case true:
							result = .enqueued(remaining: remainingCount(limit))
							self.buffer.append(value)
						case false:
							result = .dropped(value)
						}
					case let .bufferingNewest(limit):
						switch count < limit {
						case true:
							result = .enqueued(remaining: remainingCount(limit))
							self.buffer.append(value)
						case false:
							result = .dropped(self.buffer.removeFirst())
							self.buffer.append(value)
						}
					}

					return .resume(yieldResult: result, consumer: consumer, element: self.buffer.removeFirst())
				case (.disconnected, .empty):
					switch self.bufferPolicy {
					case .unbounded:
						result = .enqueued(remaining: .max)
						self.buffer.append(value)
					case let .bufferingOldest(limit), let .bufferingNewest(limit):
						result = .enqueued(remaining: remainingCount(limit))
						self.buffer.append(value)
					}

					return .none(yieldResult: result)
				case (.disconnected, .occupied):
					switch self.bufferPolicy {
					case .unbounded:
						result = .enqueued(remaining: .max)
						self.buffer.append(value)
					case let .bufferingOldest(limit):
						switch count < limit {
						case true:
							result = .enqueued(remaining: remainingCount(limit))
							self.buffer.append(value)
						case false:
							result = .dropped(value)
						}
					case let .bufferingNewest(limit):
						switch count < limit {
						case true:
							result = .enqueued(remaining: remainingCount(limit))
							self.buffer.append(value)
						case false:
							result = .dropped(self.buffer.removeFirst())
							self.buffer.append(value)
						}
					}

					return .none(yieldResult: result)
				}
			case .terminated: // TODO: Are these all reachable?
				switch (consumerState, bufferState) {
				case (.connected, .empty): // I don't think so??
					result = .terminated

					return .resume(yieldResult: result, consumer: consumer, element: nil)
				case (.connected, .occupied):
					result = .terminated

					return .resume(yieldResult: result, consumer: consumer, element: self.buffer.removeFirst())
				case (.disconnected, .empty), (.disconnected, .occupied):
					result = .terminated

					return .none(yieldResult: result)
				}
			}
		}

		switch action {
		case let .resume(yieldResult, consumer, element): // UnsafeSendable needed. 'yieldResult' could theoretically hold 'value' too.
			consumer?.resume(returning: .success(UnsafeSendable(element).take()))

			return yieldResult
		case let .none(yieldResult):
			return yieldResult
		}
	}

	func next(_ consumer: Consumer) {
		let action: NextAction = lock.whileLocked {
			switch self.consumerState {
			case .connected:
				return .failConcurrentAccess
			case .disconnected:
				switch self.bufferState {
				case .empty:
					switch self.state {
					case .terminated:
						return .resume(element: nil)
					case .active:
						self.consumer = consumer

						return .suspend
					}
				case .occupied:
					let element = self.buffer.removeFirst()

					return .resume(element: element)
				}
			}
		}

		switch action {
		case let .resume(element):
			consumer.resume(returning: .success(element))
		case .suspend:
			return
		case .failConcurrentAccess:
			fatalError("Concurrent iteration detected")
		}
	}

	func next() async throws(Failure) -> Element? {
		try await withTaskCancellationHandler {
			await withCheckedContinuation { consumer in
				self.next(consumer)
			}
		} onCancel: {
			self.terminate(.cancelled)
		}.get()
	}
}
