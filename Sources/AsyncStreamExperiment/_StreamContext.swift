
final class _StreamContext<Element, Failure: Error> {
  typealias Producer = nonisolated(nonsending) () async throws(Failure) -> Element?

  let _storage: _Storage<Element, Failure>?
  let produce: Producer

  init(
    _storage: _Storage<Element, Failure>? = nil,
    produce: @escaping Producer) {
      self._storage = _storage
      self.produce = produce
    }

  deinit {
    self._storage?.terminate(.cancelled)
  }
}
