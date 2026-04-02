
import Collections

@safe
final class _Storage<Element, Failure: Error>: @unchecked Sendable {
  @unsafe
  struct _StateMachine: ~Copyable {
    typealias Buffer = Deque<Element>
    typealias Consumer = UnsafeContinuation<Result<Element?, Failure>, Never>
    typealias Consumers = Deque<Consumer>
    typealias TerminationHandler = @Sendable (Continuation.Termination) -> Void
    
    @unsafe
    enum State: ~Copyable {
      struct Idle: ~Copyable {
        var buffer: Buffer
        let bufferingPolicy: Continuation.BufferingPolicy
        var terminationHandler: TerminationHandler?
      }

      @unsafe
      struct Waiting: ~Copyable {
        var consumers: Consumers
        let bufferingPolicy: Continuation.BufferingPolicy
        var terminationHandler: TerminationHandler?
      }

      struct Draining: ~Copyable {
        var failure: Failure?
        var buffer: Buffer
        var terminationHandler: TerminationHandler?
      }

      struct Terminated: ~Copyable {
        var failure: Failure?
        var terminationHandler: TerminationHandler?
      }

      case idle(Idle)

      case waiting(Waiting)

      case draining(Draining)

      case terminated(Terminated)
    }

    @unsafe
    enum YieldAction {
      case resume(
        consumer: Consumer,
        element: Element,
        yieldResult: Continuation.YieldResult
      )

      case none(yieldResult: Continuation.YieldResult)
    }

    @unsafe
    enum TerminateAction {
      case callHandlerAndResume(
        terminationHandler: TerminationHandler?,
        consumers: Consumers,
        failure: Failure?
      )

      case callHandler(terminationHandler: TerminationHandler?)

      case none
    }

    enum NextAction {
      case resume(element: Element?)

      case `throw`(failure: Failure)

      case suspend
    }

    var state: State

    init(bufferingPolicy: Continuation.BufferingPolicy) {
      unsafe self.state = unsafe .idle(.init(
          buffer: [],
          bufferingPolicy: bufferingPolicy,
          terminationHandler: nil
        )
      )
    }

    init(state: consuming State) {
      unsafe self.state = unsafe state
    }
  }

  private let lock: Lock

  private var _stateMachine: _StateMachine

  init(bufferingPolicy: Continuation.BufferingPolicy) {
    unsafe self.lock = unsafe .create()
    unsafe self._stateMachine = unsafe _StateMachine(bufferingPolicy: bufferingPolicy)
  }

  deinit {
    self.terminate(.cancelled)
    unsafe Lock.destroy(self.lock)
  }
}

extension _Storage._StateMachine {
  func getOnTermination() -> TerminationHandler? {
    switch unsafe self.state {
    case .idle(let idle):
      return idle.terminationHandler

    case .waiting(let waiting):
      return unsafe waiting.terminationHandler

    case .draining(let draining):
      return draining.terminationHandler

    case .terminated(let terminated):
      return terminated.terminationHandler
    }
  }

  mutating func setOnTermination(_ newValue: TerminationHandler?) {
    switch unsafe consume self.state { // TODO: Set a TerminationHandler only in certain states
    case .idle(var idle):
      idle.terminationHandler = newValue
      unsafe self = unsafe .init(state: .idle(idle))

    case .waiting(var waiting):
      unsafe waiting.terminationHandler = newValue
      unsafe self = unsafe .init(state: .waiting(waiting))

    case .draining(var draining):
      draining.terminationHandler = newValue
      unsafe self = unsafe .init(state: .draining(draining))

    case .terminated(var terminated):
      terminated.terminationHandler = newValue
      unsafe self = unsafe .init(state: .terminated(terminated))
    }
  }

  mutating func yield(_ value: consuming sending Element) -> YieldAction {
    switch unsafe consume self.state {
    case .idle(var idle):
      switch idle.bufferingPolicy {
      case .unbounded:
        idle.buffer.append(value)
        unsafe self = unsafe .init(state: .idle(idle))
        return unsafe .none(yieldResult: .enqueued(remaining: .max))

      case .bufferingOldest(let limit):
        switch idle.buffer.count < limit {
        case true:
          idle.buffer.append(value)
          let bufferCount = idle.buffer.count
          unsafe self = unsafe .init(state: .idle(idle))
          return unsafe .none(yieldResult: .enqueued(remaining: limit - bufferCount))

        case false:
          unsafe self = unsafe .init(state: .idle(idle))
          return unsafe .none(yieldResult: .dropped(value))
        }

      case .bufferingNewest(let limit):
        switch limit {
        case _ where idle.buffer.count < limit && limit > .zero:
          idle.buffer.append(value)
          let bufferCount = idle.buffer.count
          unsafe self = unsafe .init(state: .idle(idle))
          return unsafe .none(yieldResult: .enqueued(remaining: limit - bufferCount))

        case _ where idle.buffer.count >= limit && limit > .zero:
          let droppedValue = idle.buffer.removeFirst()
          idle.buffer.append(value)
          unsafe self = unsafe .init(state: .idle(idle))
          return unsafe .none(yieldResult: .dropped(droppedValue))

        default:
          unsafe self = unsafe .init(state: .idle(idle))
          return unsafe .none(yieldResult: .dropped(value))
        }
      }

    case .waiting(var waiting):
      let bufferingPolicy = unsafe waiting.bufferingPolicy
      let consumer = unsafe waiting.consumers.removeFirst()

      switch unsafe waiting.consumers.isEmpty {
      case true:
        unsafe self = unsafe .init(state: .idle(.init(
              buffer: [],
              bufferingPolicy: waiting.bufferingPolicy,
              terminationHandler: waiting.terminationHandler
            )
          )
        )

      case false:
        unsafe self = unsafe .init(state: .waiting(waiting))
      }

      switch bufferingPolicy {
      case .unbounded:
        return unsafe .resume(
          consumer: consumer,
          element: value,
          yieldResult: .enqueued(remaining: .max)
        )

      case .bufferingOldest(let limit), .bufferingNewest(let limit):
        return unsafe .resume(
          consumer: consumer,
          element: value,
          yieldResult: .enqueued(remaining: limit)
        )
      }

    case .draining(let draining):
      unsafe self = unsafe .init(state: .draining(draining))
      return unsafe .none(yieldResult: .terminated)

    case .terminated(let terminated):
      unsafe self = unsafe .init(state: .terminated(terminated))
      return unsafe .none(yieldResult: .terminated)
    }
  }

  mutating func terminate(_ failure: consuming Failure?) -> TerminateAction {
    switch unsafe consume self.state {
    case .idle(var idle):
      switch idle.buffer.isEmpty {
      case true:
        unsafe self = unsafe .init(state: .terminated(.init(failure: failure)))
        return unsafe .callHandler(terminationHandler: idle.terminationHandler.take())

      case false:
        unsafe self = unsafe .init(state: .draining(.init(failure: failure, buffer: idle.buffer)))
        return unsafe .callHandler(terminationHandler: idle.terminationHandler.take())
      }

    case .waiting(var waiting):
      unsafe self = unsafe .init(state: .terminated(.init(failure: .none)))
      return unsafe .callHandlerAndResume(
        terminationHandler: waiting.terminationHandler.take(),
        consumers: waiting.consumers,
        failure: failure
      )

    case .draining(let draining):
      unsafe self = unsafe .init(state: .draining(draining))
      return unsafe .none

    case .terminated(let terminated):
      unsafe self = unsafe .init(state: .terminated(terminated))
      return unsafe .none
    }
  }

  mutating func next(_ consumer: consuming Consumer) -> NextAction {
    switch unsafe consume self.state {
    case .idle(var idle):
      switch idle.buffer.isEmpty {
      case true:
        unsafe self = unsafe .init(state: .waiting(.init(
              consumers: [consumer],
              bufferingPolicy: idle.bufferingPolicy,
              terminationHandler: idle.terminationHandler
            )
          )
        )
        return .suspend

      case false:
        let element = idle.buffer.removeFirst()
        unsafe self = unsafe .init(state: .idle(idle))
        return .resume(element: element)
      }

    case .waiting(var waiting):
      unsafe waiting.consumers.append(consumer)
      unsafe self = unsafe .init(state: .waiting(waiting))
      return .suspend

    case .draining(var draining):
      guard
        let element = draining.buffer.popFirst()
      else {
        unsafe self = unsafe .init(state: .terminated(.init(
              failure: .none,
              terminationHandler: draining.terminationHandler
            )
          )
        )

        switch draining.failure {
        case .some(let failure):
          return .throw(failure: failure)

        case .none:
          return .resume(element: nil)
        }
      }

      switch draining.buffer.isEmpty {
      case true:
        unsafe self = unsafe .init(state: .terminated(.init(
              failure: draining.failure,
              terminationHandler: draining.terminationHandler
            )
          )
        )
        return .resume(element: element)

      case false:
        unsafe self = unsafe .init(state: .draining(draining))
        return .resume(element: element)
      }

    case .terminated(let terminated):
      unsafe self = unsafe .init(state: .terminated(.init(
            failure: .none,
            terminationHandler: nil
          )
        )
      )

      switch terminated.failure {
      case .some(let failure):
        return .throw(failure: failure)

      case .none:
        return .resume(element: nil)
      }
    }
  }
}

extension _Storage {
  func getOnTermination() -> _StateMachine.TerminationHandler? {
    withLock { state in
      return unsafe state.getOnTermination()
    }
  }

  func setOnTermination(_ newValue: _StateMachine.TerminationHandler?) {
    withLock { state in
      unsafe state.setOnTermination(newValue)
    }
  }

  func yield(_ value: consuming sending Element) -> Continuation.YieldResult {
    var disconnectedValue = UnsafeSendable(value: Optional(value))

    let action = withLock { state in
      let value = disconnectedValue.swap(newValue: nil)!
      return unsafe state.yield(value)
    }

    switch unsafe action {
    case .resume(let consumer, let element, let yieldResult):
      unsafe consumer.resume(returning: .success(UnsafeSendable(value: element).take()))
      return yieldResult

    case .none(let yieldResult):
      return yieldResult
    }
  }

  func terminate(_ terminationReason: Continuation.Termination) {
    let failure: Failure?

    switch terminationReason {
    case .finished(let withFailure):
      failure = withFailure

    case .cancelled:
      failure = nil
    }

    let action = withLock { state in
      return unsafe state.terminate(failure)
    }

    switch unsafe action {
    case .callHandlerAndResume(
      let terminationHandler,
      var consumers,
      let failure
    ):
      terminationHandler?(terminationReason)

      if let failure {
        let consumer = unsafe consumers.popFirst()
        unsafe consumer?.resume(returning: .failure(failure))
      }

      while let consumer = unsafe consumers.popFirst() {
        unsafe consumer.resume(returning: .success(nil))
      }

    case .callHandler(let terminationHandler):
      terminationHandler?(terminationReason)

    case .none:
      return
    }
  }

  func next(_ consumer: consuming _StateMachine.Consumer) {
    let action = withLock { state in
      unsafe state.next(consumer)
    }

    switch action {
    case .resume(let element):
      unsafe consumer.resume(returning: .success(element))

    case .throw(let failure):
      unsafe consumer.resume(returning: .failure(failure))

    case .suspend:
      return
    }
  }

  nonisolated(nonsending) func next() async throws(Failure) -> Element? {
    return try await withTaskCancellationHandler {
      return unsafe await withUnsafeContinuation { consumer in
        unsafe self.next(consumer)
      }
    } onCancel: {
      self.terminate(.cancelled)
    }.get()
  }
}

extension _Storage {
  @safe
  func withLock<Value>(_ action: (inout _StateMachine) -> Value) -> Value {
    unsafe lock.lock()

    defer { unsafe lock.unlock() }

    return unsafe action(&self._stateMachine)
  }
}
