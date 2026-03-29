
import Collections

internal final class _Storage<Element, Failure: Error>: @unchecked Sendable {
  typealias Buffer = Deque<Element>
  typealias Consumer = UnsafeContinuation<Result<Element?, Failure>, Never>
  typealias Consumers = Deque<UnsafeContinuation<Result<Element?, Failure>, Never>>
  typealias TerminationHandler = @Sendable (Continuation.Termination) -> Void

  private enum State {
    case buffering(
      buffer: Buffer)

    case suspended(
      consumers: Consumers)

    case draining(
      buffer: Buffer,
      failure: Failure? = nil)

    case terminated(
      failure: Failure? = nil)
  }

  private enum YieldAction {
    case resume(
      consumer: Consumer,
      element: Element?)

    case none
  }

  private enum NextAction {
    case resume(
      element: Element?)

    case `throw`(
      failure: Failure)

    case suspend
  }

  private enum TerminateAction {
    case callHandlerAndResume(
      terminationHandler: TerminationHandler?,
      consumers: Consumers,
      failure: Failure?)

    case callHandler(
      terminationHandler: TerminationHandler?)

    case none
  }

  private let lock = Lock.create()
  private let bufferingPolicy: Continuation.BufferingPolicy

  private var state = State.buffering(buffer: [])
  private var onTermination: TerminationHandler?

  init(bufferingPolicy: Continuation.BufferingPolicy) {
    self.bufferingPolicy = bufferingPolicy
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
      case .buffering, .suspended:
        self.onTermination = newValue

      case .draining, .terminated:
        return
      }
    }
  }

  func yield(_ value: sending Element) -> Continuation.YieldResult {
    let (
      result,
      action
    ): (Continuation.YieldResult, YieldAction) = lock.withLock {
      switch self.state {
      case var .buffering(buffer):
        switch self.bufferingPolicy {
        case .unbounded:
          buffer.append(value)
          self.state = .buffering(buffer: buffer)
          return (
            result: .enqueued(remaining: .max),
            action: .none)

        case let .bufferingOldest(limit):
          switch buffer.count < limit {
          case true:
            buffer.append(value)
            self.state = .buffering(buffer: buffer)
            return (
              result: .enqueued(remaining: limit - buffer.count),
              action: .none)

          case false:
            return (
              result: .dropped(value),
              action: .none)
          }

        case let .bufferingNewest(limit):
          switch limit {
          case _ where buffer.count < limit && limit > .zero:
            buffer.append(value)
            self.state = .buffering(buffer: buffer)
            return (
              result: .enqueued(remaining: limit - buffer.count),
              action: .none)

          case _ where buffer.count >= limit && limit > .zero:
            let droppedValue = buffer.removeFirst()
            buffer.append(value)
            self.state = .buffering(buffer: buffer)
            return (
              result: .dropped(droppedValue),
              action: .none)

          default:
            return (
              result: .dropped(value),
              action: .none)
          }
        }

      case var .suspended(consumers):
        let consumer = consumers.removeFirst()

        switch consumers.isEmpty {
        case true:
          self.state = .buffering(buffer: [])
        case false:
          self.state = .suspended(consumers: consumers)
        }

        switch self.bufferingPolicy {
        case .unbounded:
          return (
            result: .enqueued(remaining: .max),
            action: .resume(consumer: consumer, element: value))

        case let .bufferingOldest(limit), let .bufferingNewest(limit):
          return (
            result: .enqueued(remaining: limit),
            action: .resume(consumer: consumer, element: value))
        }

      case .draining, .terminated:
        return (
          result: .terminated,
          action: .none)
      }
    }

    switch action {
    case let .resume(consumer, element):
      let element = _UnsafeSendable(element).take()
      consumer.resume(returning: .success(element))
      return result

    case .none:
      return result
    }
  }

  private
  func next(_ consumer: Consumer) {
    let action: NextAction = lock.withLock {
      switch self.state {
      case var .buffering(buffer):
        switch buffer.isEmpty {
        case true:
          self.state = .suspended(consumers: [consumer])
          return .suspend

        case false:
          let element = buffer.removeFirst()
          self.state = .buffering(buffer: buffer)
          return .resume(element: element)
        }

      case var .suspended(consumers):
        consumers.append(consumer)
        self.state = .suspended(consumers: consumers)
        return .suspend

      case .draining(var buffer, let failure):
        switch buffer.isEmpty {
        case true:
          self.state = .terminated()
          switch failure {
          case .none:
            return .resume(element: nil)

          case let .some(failure):
            return .throw(failure: failure)
          }

        case false:
          let element = buffer.removeFirst()
          self.state = .draining(buffer: buffer, failure: failure)
          return .resume(element: element)
        }

      case let .terminated(failure):
        self.state = .terminated()
        switch failure {
        case .none:
          return .resume(element: nil)

        case let .some(failure):
          return .throw(failure: failure)
        }
      }
    }

    switch action {
    case let .resume(element):
      consumer.resume(returning: .success(element))

    case let .throw(failure):
      consumer.resume(returning: .failure(failure))

    case .suspend:
      break
    }
  }

  nonisolated(nonsending)
  func next() async throws(Failure) -> Element? {
    return try await withTaskCancellationHandler {
      return await withUnsafeContinuation { consumer in
        self.next(consumer)
      }
    } onCancel: {
      self.terminate(.cancelled)
    }.get()
  }

  func terminate(_ terminationReason: Continuation.Termination) {
    let failure: Failure?

    switch terminationReason {
    case let .finished(withFailure):
      failure = withFailure

    case .cancelled:
      failure = nil
    }

    let action: TerminateAction = lock.withLock {
      switch self.state {
      case let .buffering(buffer):
        switch buffer.isEmpty {
        case true:
          self.state = .terminated(failure: failure)

        case false:
          self.state = .draining(buffer: buffer, failure: failure)
        }
        return .callHandler(
          terminationHandler: self.onTermination.take())

      case let .suspended(consumers):
        self.state = .terminated()
        return .callHandlerAndResume(
          terminationHandler: self.onTermination.take(),
          consumers: consumers,
          failure: failure)

      case .draining, .terminated:
        return .none
      }
    }

    switch action {
    case .callHandlerAndResume(
      terminationHandler: let terminationHandler,
      consumers: var consumers,
      failure: let failure):
      terminationHandler?(terminationReason)

      if let failure {
        let consumer = consumers.popFirst()
        consumer?.resume(returning: .failure(failure))
      }

      while let element = consumers.popFirst() {
        element.resume(returning: .success(nil))
      }

    case let .callHandler(terminationHandler: terminationHandler):
      terminationHandler?(terminationReason)

    case .none:
      break
    }
  }
}
