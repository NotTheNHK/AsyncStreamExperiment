
// MARK: - BufferingPolicy

extension AsyncStreamV2.Continuation.BufferingPolicy {
  func asStorageBufferingPolicy()
  -> _Storage<Element, Never>.Continuation.BufferingPolicy {
    switch self {
    case .unbounded:
      return .unbounded
    case let .bufferingOldest(limit):
      return .bufferingOldest(limit)
    case let .bufferingNewest(limit):
      return .bufferingNewest(limit)
    }
  }
}

// MARK: - Termination

extension AsyncStreamV2.Continuation.Termination {
  func asStorageTermination()
  -> _Storage<Element, Never>.Continuation.Termination {
    switch self {
    case .finished:
      return .finished(nil)
    case .cancelled:
      return .cancelled
    }
  }
}

extension _Storage.Continuation.Termination {
  func asStreamTermination()
  -> AsyncStreamV2<Element>.Continuation.Termination {
    switch self {
    case .finished:
      return .finished
    case .cancelled:
      return .cancelled
    }
  }
}

// MARK: - TerminationHandler

extension AsyncStreamV2.Continuation {
  internal typealias StorageTerminationHandler =
    @Sendable (_Storage<Element, Never>.Continuation.Termination) -> Void

  internal typealias StreamTerminationHandler =
    @Sendable (Termination) -> Void

  func adaptToStreamTerminationHandler(
    _ onTermination: StorageTerminationHandler?)
  -> StreamTerminationHandler? {
    guard
      let onTermination
    else { return nil }

    return { @Sendable termination in
      onTermination(termination.asStorageTermination())
    }
  }

  func adaptToStorageTerminationHandler(
    _ onTermination: StreamTerminationHandler?)
  -> StorageTerminationHandler? {
    guard
      let onTermination
    else { return nil }

    return { @Sendable termination in
      onTermination(termination.asStreamTermination())
    }
  }
}

// MARK: - YieldResult

extension _Storage.Continuation.YieldResult {
  func asStreamYieldResult()
  -> AsyncStreamV2<Element>.Continuation.YieldResult {
    switch self {
    case let .enqueued(remaining):
      return .enqueued(remaining: remaining)
    case let .dropped(element):
      return .dropped(element)
    case .terminated:
      return .terminated
    }
  }
}
