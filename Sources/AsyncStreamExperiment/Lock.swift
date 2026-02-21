//
// Lock.swift
// AsyncStreamExperiment
//
// Created by NotTheNHK on 2/11/26 at 11:36 PM
//

import Foundation

typealias Lock = UnsafeMutablePointer<os_unfair_lock>

extension Lock {
	static func createLock() -> Lock {
		let lock = Lock.allocate(capacity: 1)

		lock.initialize(to: .init())

		return lock
	}

	static func destructLock(_ lock: Lock) {
		lock.deinitialize(count: 1)

		lock.deallocate()
	}

	func whileLocked<Value, Failure>(_ action: () throws(Failure) -> Value) throws(Failure) -> Value {
		os_unfair_lock_lock(self)

		defer { os_unfair_lock_unlock(self) }

		return try action()
	}
}
