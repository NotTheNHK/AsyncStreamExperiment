struct SomeError: Error, Equatable {
	var value = Int.random(in: 0..<100)
}

import Testing
@testable import AsyncStreamExperiment

@Test("unfolding closure inherits callers executor")
func unfoldingClosureInheritsCallersExecutor() async throws { // TODO: How can we model this?
	final class E: SerialExecutor {
		nonisolated(unsafe) var confirmCount = 0

		func enqueue(_ job: consuming ExecutorJob) {
			print("\nStart Work on 'E'")
			job.runSynchronously(on: asUnownedSerialExecutor())
			confirmCount += 1
			print("Finish Work on 'E'\n")
		}
	}

	actor A {
		private let e = E()

		nonisolated var confirmCount: Int {
			e.confirmCount
		}

		nonisolated var unownedExecutor: UnownedSerialExecutor {
			e.asUnownedSerialExecutor()
		}

		func work() async throws {
			print(1)

			let stream = AsyncThrowingStreamV2<Void, Never> {
				print(3)

				await Task.yield()

				print(4)

				return nil
			}

			print(2)

			for try await _ in stream {}
		}
	}

	let a = A()

	try await a.work()

	#expect(a.confirmCount == 2)
}
