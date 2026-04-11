
@safe
final class _UnfoldingStorage<Element, Failure: Error>: @unchecked Sendable {
  typealias Producer = (nonisolated(nonsending) () async throws(Failure) -> Element?)?
  typealias OnCancel = (@Sendable () -> Void)?

  enum State {
    case producing(
      producer: Producer,
      onCancel: OnCancel
    )

    case terminated
  }

  private let lock: Lock
  private var state: State

  init(
    producer: Producer,
    onCancel: OnCancel
  ) {
    unsafe self.lock = unsafe .create()
    self.state = .producing(
      producer: producer,
      onCancel: onCancel
    )
  }

  deinit {
    unsafe Lock.destroy(self.lock)
  }
}

extension _UnfoldingStorage {
  nonisolated(nonsending) func next() async throws(Failure) -> Element? {
    let producer = withLock { state in
      switch state {
      case .producing(let producer, _):
        return producer

      case .terminated:
        return nil
      }
    }

    switch try await producer?() {
    case .some(let element):
      return element

    case .none:
      withLock { state in
        state = .terminated
      }
      return nil
    }
  }

  func terminate() {
    let onCancel = withLock { state in
      switch state {
      case .producing(_, onCancel: let onCancel):
        state = .terminated
        return onCancel

      case .terminated:
        return nil
      }
    }

    onCancel?()
  }
}

extension _UnfoldingStorage {
  @safe
  private func withLock<Value: ~Copyable>(
    _ action: (inout State) -> Value
  ) -> Value {
    unsafe lock.lock()

    defer { unsafe self.lock.unlock() }

    return action(&self.state)
  }
}
