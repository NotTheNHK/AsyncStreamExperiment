
import os

typealias Lock = os_unfair_lock_t

extension Lock {
	static func create() -> Lock {
		let lock = Lock.allocate(capacity: 1)

    unsafe lock.initialize(to: .init())

    return unsafe lock
	}

	static func destroy(_ lock: Lock) {
    unsafe lock.deinitialize(count: 1)

    unsafe lock.deallocate()
	}

	func lock() {
    unsafe os_unfair_lock_lock(self)
	}

	func unlock() {
    unsafe os_unfair_lock_unlock(self)
	}
}
