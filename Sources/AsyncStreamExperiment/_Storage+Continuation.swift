
extension _Storage {
  internal struct Continuation {
    internal enum BufferingPolicy {
      case unbounded

      case bufferingOldest(Int)

      case bufferingNewest(Int)
    }

    internal enum YieldResult {
      case enqueued(remaining: Int)

      case dropped(Element)

      case terminated
    }

    internal enum Termination {
      case finished(Failure?)

      case cancelled
    }
  }
}
