
final class _StreamContext<Element, Failure: Error> {
	let _storage: _Storage<Element, Failure>?
	let produce: nonisolated(nonsending) () async throws(Failure) -> Element?

	init(
		_storage: _Storage<Element, Failure>? = nil,
		produce: nonisolated(nonsending) sending @escaping () async throws(Failure) -> Element?) {
			self._storage = _storage
			self.produce = produce
		}
}
