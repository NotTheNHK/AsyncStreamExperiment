
final class _ContinuationContext<Element, Failure: Error> {
	let _storage: _Storage<Element, Failure>

	init(_storage: _Storage<Element, Failure>) {
		self._storage = _storage
	}

	deinit {
		self._storage.terminate(.cancelled)
	}
}
