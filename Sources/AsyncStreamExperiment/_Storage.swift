//
// _Storage.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/11/26 at 11:51 PM
//

import Collections

final class _Storage<Element, Failure: Error>: @unchecked Sendable {
	typealias Consumer = UnsafeContinuation<Result<Element?, Failure>, Never>
	typealias Consumers = Deque<UnsafeContinuation<Result<Element?, Failure>, Never>>
	typealias TerminationHandler = @Sendable (Continuation.Termination) -> Void

	enum State {
		case activeIdle(buffer: Deque<Element>)

		case activeWaiting(consumers: Consumers)

		case draining(buffer: Deque<Element>)

		case terminated
	}

	enum TerminateAction {
		case callHandlerAndResume(TerminationHandler?, Consumers)

		case callHandler(TerminationHandler?)

		case none
	}

	enum YieldAction {
		case resume(consumer: Consumer, element: Element?)

		case none
	}

	enum NextAction {
		case resume(element: Element?)

		case suspend
	}

	private let lock = Lock.create()
	private let bufferPolicy: Continuation.BufferingPolicy

	private var state = State.activeIdle(buffer: Deque())
	private var onTermination: TerminationHandler?

	init(bufferPolicy: Continuation.BufferingPolicy) {
		self.bufferPolicy = bufferPolicy
	}

	deinit {
		self.onTermination?(.cancelled)
		Lock.destroy(self.lock)
	}
}

extension _Storage {
	func getOnTermination() -> TerminationHandler? {
		lock.withLock {
			return self.onTermination
		}
	}

	func setOnTermination(_ newValue: TerminationHandler?) {
		lock.withLock {
			self.onTermination = newValue
		}
	}

	func terminate(_ terminationReason: Continuation.Termination) {
		let action: TerminateAction = lock.withLock {
			switch self.state {
			case let .activeIdle(buffer):
				switch buffer.isEmpty {
				case true:
					self.state = .terminated

				case false:
					self.state = .draining(buffer: buffer)
				}
				return .callHandler(self.onTermination.take())

			case let .activeWaiting(consumers):
				self.state = .terminated
				return .callHandlerAndResume(self.onTermination.take(), consumers)

			case .draining, .terminated:
				return .none
			}
		}

		switch action {
		case .callHandlerAndResume(let terminationHandler, var consumers):
			terminationHandler?(terminationReason)
			consumers.removeAll { consumer in // TODO: Don't like this
				consumer.resume(returning: .success(nil))
				return true
			}

		case let .callHandler(terminationHandler):
			terminationHandler?(terminationReason)

		case .none:
			break
		}
	}

	func yield(_ value: sending Element) -> Continuation.YieldResult {
		let (result, action): (Continuation.YieldResult, YieldAction) = lock.withLock {
			switch self.state {
			case var .activeIdle(buffer):
				switch self.bufferPolicy {
				case .unbounded:
					buffer.append(value)
					self.state = .activeIdle(buffer: buffer)
					return (.enqueued(remaining: .max), .none)

				case let .bufferingOldest(limit):
					switch buffer.count < limit {
					case true:
						buffer.append(value)
						self.state = .activeIdle(buffer: buffer)
						return (.enqueued(remaining: limit - buffer.count), .none)

					case false:
						return (.dropped(value), .none)
					}

				case let .bufferingNewest(limit):
					switch buffer.count < limit {
					case true:
						buffer.append(value)
						self.state = .activeIdle(buffer: buffer)
						return (.enqueued(remaining: limit - buffer.count), .none)

					case false:
						let droppedValue = buffer.removeFirst()
						buffer.append(value)
						self.state = .activeIdle(buffer: buffer)
						return (.dropped(droppedValue), .none)
					}
				}

			case var .activeWaiting(consumers): // TODO: Needs further refinement
				let consumer = consumers.removeFirst()

				switch consumers.isEmpty {
				case true:
					self.state = .activeIdle(buffer: Deque())
				case false:
					self.state = .activeWaiting(consumers: consumers)
				}

				switch self.bufferPolicy {
				case .unbounded:
					return (.enqueued(remaining: .max), .resume(consumer: consumer, element: value))

				case let .bufferingOldest(limit), let .bufferingNewest(limit):
					return (.enqueued(remaining: limit), .resume(consumer: consumer, element: value))
				}
			case .draining, .terminated:
				return (.terminated, .none)
			}
		}

		switch action {
		case let .resume(consumer, element):
			consumer.resume(returning: .success(UnsafeSendable(element).take()))

		case .none:
			break
		}

		return result
	}

	func next(_ consumer: Consumer) {
		let action: NextAction = lock.withLock {
			switch self.state {
			case var .activeIdle(buffer):
				switch buffer.isEmpty {
				case true:
					self.state = .activeWaiting(consumers: [consumer])
					return .suspend

				case false:
					let element = buffer.removeFirst()
					self.state = .activeIdle(buffer: buffer)
					return .resume(element: element)
				}

			case var .activeWaiting(consumers):
				consumers.append(consumer)
				self.state = .activeWaiting(consumers: consumers)
				return .suspend

			case var .draining(buffer):
				switch buffer.isEmpty {
				case true:
					self.state = .terminated
					return .resume(element: nil)

				case false:
					let element = buffer.removeFirst()
					self.state = .draining(buffer: buffer)
					return .resume(element: element)
				}
			case .terminated:
				return .resume(element: nil)
			}
		}

		switch action {
		case let .resume(element):
			consumer.resume(returning: .success(element))

		case .suspend:
			break
		}
	}

	func next() async throws(Failure) -> Element? {
		try await withTaskCancellationHandler {
			await withUnsafeContinuation { consumer in
				self.next(consumer)
			}
		} onCancel: {
			self.terminate(.cancelled)
		}.get()
	}
}
