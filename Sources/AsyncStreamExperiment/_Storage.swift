//
// _Storage.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/11/26 at 11:51 PM
//

import Collections

final class _Storage<Element, Failure: Error>: @unchecked Sendable {
	typealias Consumer = UnsafeContinuation<Result<Element?, Failure>, Never>
	typealias TerminationHandler = @Sendable (Continuation.Termination) -> Void

	enum State {
		case activeIdle(buffer: Deque<Element>)

		case activeWaiting(consumer: Consumer)

		case draining(buffer: Deque<Element>, failure: Failure? = nil)

		case terminated(failure: Failure? = nil)
	}

	enum YieldAction {
		case resume(consumer: Consumer, element: Element?)

		case none
	}

	enum NextAction {
		case resume(element: Element?)

		case throwing(failure: Failure)

		case suspend

		case failConcurrentAccess
	}

	enum TerminateAction {
		case callHandlerAndResume(terminationHandler: TerminationHandler?, consumer: Consumer, failure: Failure?)

		case callHandler(terminationHandler: TerminationHandler?)

		case none
	}

	private let lock = Lock.create()
	private let bufferPolicy: Continuation.BufferingPolicy

	private var state = State.activeIdle(buffer: Deque())
	private var onTermination: TerminationHandler?

	init(bufferPolicy: Continuation.BufferingPolicy) {
		self.bufferPolicy = bufferPolicy
	}

	deinit {
		self.terminate(.cancelled)
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
			switch self.state {
			case .activeIdle, .activeWaiting:
				self.onTermination = newValue
			default:
				return
			}
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
					switch limit {
					case let limit where limit <= .zero:
						return (.dropped(value), .none)

					case let limit where buffer.count < limit:
						buffer.append(value)
						self.state = .activeIdle(buffer: buffer)
						return (.enqueued(remaining: limit - buffer.count), .none)

					default:
						let droppedValue = buffer.removeFirst()
						buffer.append(value)
						self.state = .activeIdle(buffer: buffer)
						return (.dropped(droppedValue), .none)
					}
				}

			case let .activeWaiting(consumer):
				self.state = .activeIdle(buffer: Deque())
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
			let element = UnsafeSendable(element).take()
			consumer.resume(returning: .success(element))

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
					self.state = .activeWaiting(consumer: consumer)
					return .suspend

				case false:
					let element = buffer.removeFirst()
					self.state = .activeIdle(buffer: buffer)
					return .resume(element: element)
				}

			case .activeWaiting:
				return .failConcurrentAccess

			case .draining(var buffer, let failure):
				switch buffer.isEmpty {
				case true:
					self.state = .terminated()
					switch failure {
					case .none:
						return .resume(element: nil)

					case let .some(failure):
						return .throwing(failure: failure)
					}

				case false:
					let element = buffer.removeFirst()
					self.state = .draining(buffer: buffer, failure: failure)
					return .resume(element: element)
				}

			case let .terminated(failure):
				switch failure {
				case .none:
					return .resume(element: nil)

				case let .some(failure):
					return .throwing(failure: failure)
				}
			}
		}

		switch action {
		case let .resume(element):
			consumer.resume(returning: .success(element))

		case let .throwing(failure):
			consumer.resume(returning: .failure(failure))

		case .suspend:
			break

		case .failConcurrentAccess:
			fatalError("Concurrent iteration detected")
		}
	}

	func terminate(_ terminationReason: Continuation.Termination) {
		let action: TerminateAction = lock.withLock {
			let failure: Failure?

			switch terminationReason {
			case let .finished(withFailure):
				failure = withFailure

			case .cancelled:
				failure = nil
			}

			switch self.state {
			case let .activeIdle(buffer):
				switch buffer.isEmpty {
				case true:
					self.state = .terminated(failure: failure)

				case false:
					self.state = .draining(buffer: buffer, failure: failure)
				}
				return .callHandler(
					terminationHandler: self.onTermination.take())

			case let .activeWaiting(consumer):
				self.state = .terminated()
				return .callHandlerAndResume(
					terminationHandler: self.onTermination.take(),
					consumer: consumer,
					failure: failure)

			case .draining, .terminated:
				return .none
			}
		}

		switch action {
		case .callHandlerAndResume(
			let terminationHandler,
			let consumer,
			let failure):
			terminationHandler?(terminationReason)

			switch failure {
			case .none:
				consumer.resume(returning: .success(nil))

			case let .some(failure):
				consumer.resume(returning: .failure(failure))
			}

		case .callHandler(let terminationHandler):
			terminationHandler?(terminationReason)

		case .none:
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
