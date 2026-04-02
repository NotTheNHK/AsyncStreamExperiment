
import Collections

final class _Storage<Element, Failure: Error>: @unchecked Sendable {
  struct _StateMachine: ~Copyable {
    typealias Buffer = Deque<Element>
    typealias Consumer = UnsafeContinuation<Result<Element, Failure>, Never>
    typealias Consumers = Deque<Consumer>
    typealias TerminationHandler = @Sendable (Continuation.Termination) -> Void

    enum YieldAction {
      case resume(
        consumer: Consumer,
        element: Element,
        yieldResult: Continuation.YieldResult
      )

      case none(yieldResult: Continuation.YieldResult)
    }

    enum NextAction {
      case resume(element: Element?)

      case `throw`(failure: Failure)

      case suspend
    }

    enum TerminateAction {
      case callHandlerAndResume(
        terminationHandler: TerminationHandler,
        consumers: Consumers,
        failure: Failure?
      )

      case callHandler(terminationHandler: TerminationHandler)
    }

    enum State: ~Copyable {
      struct Idle: ~Copyable {
        var buffer: Buffer
        let bufferingPolicy: Continuation.BufferingPolicy
        var terminationHandler: TerminationHandler?
      }

      struct Waiting: ~Copyable {
        var consumers: Consumers
        let bufferingPolicy: Continuation.BufferingPolicy
        var terminationHandler: TerminationHandler?
      }

      struct Draining: ~Copyable {
        let buffer: Buffer
        var terminationHandler: TerminationHandler?
      }

      struct Terminated: ~Copyable {
        var terminationHandler: TerminationHandler?
      }

      case idle(Idle)

      case waiting(Waiting)

      case draining(Draining)

      case terminated(Terminated)
    }

    var state: State

    init(bufferingPolicy: Continuation.BufferingPolicy) {
      self.state = .idle(
        .init(
          buffer: [],
          bufferingPolicy: bufferingPolicy,
          terminationHandler: nil
        )
      )
    }

    init(state: consuming State) {
      self.state = state
    }
  }

  private let lock: Lock

  private var _stateMachine: _StateMachine

  init(bufferingPolicy: Continuation.BufferingPolicy) {
    self.lock = .create()
    self._stateMachine = _StateMachine(bufferingPolicy: bufferingPolicy)
  }

  deinit {
    Lock.destroy(self.lock)
  }
}

extension _Storage._StateMachine {
  func getOnTermination() -> TerminationHandler? {
    switch self.state {
    case .idle(let idle):
      return idle.terminationHandler
    case .waiting(let waiting):
      return waiting.terminationHandler
    case .draining(let draining):
      return draining.terminationHandler
    case .terminated(let terminated):
      return terminated.terminationHandler
    }
  }

  mutating func setOnTermination(_ newValue: TerminationHandler?) {
    switch consume self.state { // TODO: Set a TerminationHandler only in certain states
    case .idle(var idle):
      idle.terminationHandler = newValue
      self = .init(state: .idle(idle))
    case .waiting(var waiting):
      waiting.terminationHandler = newValue
      self = .init(state: .waiting(waiting))
    case .draining(var draining):
      draining.terminationHandler = newValue
      self = .init(state: .draining(draining))
    case .terminated(var terminated):
      terminated.terminationHandler = newValue
      self = .init(state: .terminated(terminated))
    }
  }

  mutating func yield(_ value: consuming sending Element) -> YieldAction {
    switch consume self.state {
    case .idle(var idle):
      switch idle.bufferingPolicy {
      case .unbounded:
        idle.buffer.append(value)
        self = .init(state: .idle(idle))
        return .none(yieldResult: .enqueued(remaining: .max))

      case .bufferingOldest(let limit):
        switch idle.buffer.count < limit {
        case true:
          idle.buffer.append(value)
          self = .init(state: .idle(idle))
          return .none(yieldResult: .enqueued(remaining: limit - idle.buffer.count))

        case false:
          self = .init(state: .idle(idle))
          return .none(yieldResult: .dropped(value))
        }

      case .bufferingNewest(let limit):
        switch limit {
        case _ where idle.buffer.count < limit && limit > .zero:
          idle.buffer.append(value)
          self = .init(state: .idle(idle))
          return .none(yieldResult: .enqueued(remaining: limit - idle.buffer.count))

        case _ where idle.buffer.count >= limit && limit > .zero:
          let droppedValue = idle.buffer.removeFirst()
          idle.buffer.append(value)
          self = .init(state: .idle(idle))
          return .none(yieldResult: .dropped(droppedValue))

        default:
          self = .init(state: .idle(idle))
          return .none(yieldResult: .dropped(value))
        }
      }

    case .waiting(var waiting):
      let consumer = waiting.consumers.removeFirst()

      switch waiting.consumers.isEmpty {
      case true:
        self = .init(
          state: .idle(
            .init(
              buffer: [],
              bufferingPolicy: waiting.bufferingPolicy,
              terminationHandler: waiting.terminationHandler
            )
          )
        )

      case false:
        self = .init(state: .waiting(waiting))
      }

      switch waiting.bufferingPolicy {
      case .unbounded:
        return .resume(
          consumer: consumer,
          element: value,
          yieldResult: .enqueued(remaining: .max)
        )

      case .bufferingOldest(let limit), .bufferingNewest(let limit):
        return .resume(
          consumer: consumer,
          element: value,
          yieldResult: .enqueued(remaining: limit)
        )
      }

    case .draining(let draining):
      self = .init(state: .draining(draining))
      return .none(yieldResult: .terminated)

    case .terminated(let terminated):
      self = .init(state: .terminated(terminated))
      return .none(yieldResult: .terminated)
    }
  }
}

extension _Storage {
  func getOnTermination() -> _StateMachine.TerminationHandler? {
    withLock { state in
      return state.getOnTermination()
    }
  }

  func setOnTermination(_ newValue: _StateMachine.TerminationHandler?) {
    withLock { state in
      state.setOnTermination(newValue)
    }
  }

  func yield(_ value: consuming sending Element) -> Continuation.YieldResult {
    var disconnectedValue = Disconnected(value: Optional(value))

    let action = withLock { state in
      let value = disconnectedValue.swap(newValue: nil)!
      return state.yield(value)
    }

    switch action {
    case .resume(let consumer, let element, let yieldResult):
      consumer.resume(returning: .success(_UnsafeSendable(element).take()))
      return yieldResult

    case .none(let yieldResult):
      return yieldResult
    }
  }
}

extension _Storage {
  func withLock<Value>(_ action: (inout _StateMachine) -> Value) -> Value {
    lock.lock()

    defer { lock.unlock() }

    return action(&self._stateMachine)
  }
}
