
extension _Storage {
  struct Continuation {
    enum BufferingPolicy {
      case unbounded

      case bufferingOldest(Int)

      case bufferingNewest(Int)
    }

    enum YieldResult {
      case enqueued(remaining: Int)

      case dropped(Element)

      case terminated
    }

    enum Termination {
      case finished(Failure?)

      case cancelled
    }
  }
}
