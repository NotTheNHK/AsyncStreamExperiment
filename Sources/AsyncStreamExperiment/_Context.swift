//
// _Context.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 3/7/26 at 5:31 PM
//

import Foundation

final class _Context<Element, Failure: Error> {
	let _storage: _Storage<Element, Failure>?
	let produce: nonisolated(nonsending) () async throws(Failure) -> Element?

	init(
		_storage: _Storage<Element, Failure>? = nil,
		produce: nonisolated(nonsending) sending @escaping () async throws(Failure) -> Element?) {
			self._storage = _storage
			self.produce = produce
		}
}
