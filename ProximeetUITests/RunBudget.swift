import Foundation
import XCTest

/// The compute guard of the Wave verification run. The founder authorised one Xcode Cloud build, at
/// most 160 compute minutes across its two test actions, on 30 September 2026. Nothing on this side can
/// cancel a build once it runs, so the tests stop themselves. Each Wave plan gives its UI tests a budget in
/// `PROXIMEET_RUN_BUDGET_SECONDS`: Main 6,240 s and Small 2,160 s. With 600 s per action for the build,
/// the simulator's start and the domain tests, that is 9,600 s, or 160 min (`scripts/validate_project.py`,
/// check 7). Every UI test class a Wave plan selects calls `begin` as the first line of `setUpWithError`:
///
/// - With less than 60 s of the budget left, the test fails at once, before it launches anything, with a
///   message saying the budget was spent. A stopped test is a failure, never a pass or a skip.
/// - Otherwise the test may run no longer than what is left. Its `executionTimeAllowance` is lowered to
///   the whole minutes remaining whenever that is below the plans' 900-s default. XCTest rounds an
///   allowance up to whole minutes, so the value is rounded down to whole minutes and is never below 60.
/// - A test that asks for more than the default (`allow`) gets it only within what is left.
///
/// The clock starts when the first UI test of the run calls `begin`. The start is kept in the runner's
/// temporary directory, not only in memory: when a test overruns its allowance, XCTest kills the runner and
/// starts a new one for the remaining tests, and an in-memory start would give that new process the whole
/// budget again. A recorded start older than the budget plus 600 s belongs to an earlier run and is
/// replaced. If the file cannot be written, the start is kept in memory for this process.
///
/// Without the variable nothing changes: every Room and Places plan, and any local run. Then `begin` does
/// nothing and `allow` sets exactly the allowance asked for. An invalid value counts as absent.
///
/// Not actor-isolated. It is called from `setUpWithError`, and a nonisolated synchronous function can be
/// called there whatever isolation the SDK gives that override. Its one piece of memory is lock-guarded.
enum RunBudget {
    /// The test-plan environment variable: the budget, in whole seconds.
    static let variable = "PROXIMEET_RUN_BUDGET_SECONDS"
    /// The Wave plans' `defaultTestExecutionTimeAllowance`, which check 7 holds them to. A test's allowance
    /// is left alone while the budget allows more than this.
    static let planDefaultAllowance: TimeInterval = 900
    /// The least time a test is started with: XCTest's smallest allowance, one minute.
    static let leastAllowance: TimeInterval = 60
    /// A recorded start older than the budget plus this belongs to an earlier run.
    static let staleAfter: TimeInterval = 600

    private static let fileName = "proximeet-run-budget-start.txt"
    private static let memory = RunBudgetMemory()

    /// The budget in seconds, or nil (no guard) when the variable is absent or not a positive integer.
    static var budget: TimeInterval? {
        guard let raw = ProcessInfo.processInfo.environment[variable]?.trimmingCharacters(in: .whitespaces),
              let seconds = Int(raw), seconds > 0
        else { return nil }
        return TimeInterval(seconds)
    }

    /// The first line of `setUpWithError`. Throws `RunBudgetSpent`, which fails the test before it starts,
    /// once less than a minute of the budget is left. Otherwise it caps the test's allowance at the whole
    /// minutes that remain.
    static func begin(_ test: XCTestCase) throws {
        guard let budget else { return }
        let (used, remaining) = spent(of: budget)
        guard remaining >= leastAllowance else {
            print("RUN_BUDGET_SPENT \(test.name): \(Int(used)) s of \(Int(budget)) s used")
            throw RunBudgetSpent(test: test.name, budget: budget, used: used)
        }
        let cap = wholeMinutes(remaining)
        if cap < planDefaultAllowance {
            test.executionTimeAllowance = cap
        }
        print("RUN_BUDGET \(test.name): \(Int(used)) s of \(Int(budget)) s used, \(Int(remaining)) s left; "
              + "allowance \(Int(min(cap, planDefaultAllowance))) s")
    }

    /// A test that needs more than the plans' 900-s default: `seconds` with no budget, otherwise no more
    /// than the whole minutes that remain (never below one minute).
    static func allow(_ seconds: TimeInterval, _ test: XCTestCase) {
        guard let budget else {
            test.executionTimeAllowance = seconds
            return
        }
        let (_, remaining) = spent(of: budget)
        let granted = min(seconds, wholeMinutes(remaining))
        test.executionTimeAllowance = granted
        print("RUN_BUDGET \(test.name): asks for \(Int(seconds)) s, allowed \(Int(granted)) s")
    }

    /// Seconds used since the run's first `begin`, and what is left of `budget`.
    private static func spent(of budget: TimeInterval) -> (used: TimeInterval, remaining: TimeInterval) {
        let now = Date()
        let used = max(0, now.timeIntervalSince(start(budget: budget, now: now)))
        return (used, budget - used)
    }

    /// Whole minutes, rounded down, and at least one.
    private static func wholeMinutes(_ seconds: TimeInterval) -> TimeInterval {
        max(leastAllowance, (seconds / 60).rounded(.down) * 60)
    }

    /// The run's start: this process's own if it has one, else the one recorded in the runner's temporary
    /// directory by an earlier runner process of the same run, else now (recorded for the processes after it).
    private static func start(budget: TimeInterval, now: Date) -> Date {
        if let known = memory.start {
            return known
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        if let text = try? String(contentsOf: url, encoding: .utf8),
           let seconds = TimeInterval(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let recorded = Date(timeIntervalSince1970: seconds)
            let age = now.timeIntervalSince(recorded)
            if age >= -5 && age <= budget + staleAfter {
                print("RUN_BUDGET the run started \(Int(age)) s ago (recorded by an earlier runner process)")
                return memory.keep(recorded)
            }
        }
        do {
            try String(format: "%.3f\n", now.timeIntervalSince1970).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("RUN_BUDGET the start could not be recorded (\(error.localizedDescription)); kept in memory only")
        }
        return memory.keep(now)
    }
}

/// The run's start once this process knows it, behind a lock.
private final class RunBudgetMemory: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: Date?

    var start: Date? {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    /// Keeps `date` unless a start is already kept, and returns the one kept.
    func keep(_ date: Date) -> Date {
        lock.lock()
        defer { lock.unlock() }
        if let recorded {
            return recorded
        }
        recorded = date
        return date
    }
}

/// Thrown by `RunBudget.begin` once the budget is spent: XCTest reports it as the test's failure.
struct RunBudgetSpent: LocalizedError, CustomStringConvertible {
    let test: String
    let budget: TimeInterval
    let used: TimeInterval

    var description: String {
        "\(test) was stopped before it started: the Wave verification run's compute budget of \(Int(budget)) s "
            + "(\(RunBudget.variable)) was spent. \(Int(used)) s have passed since the run's first UI test began, "
            + "leaving less than the \(Int(RunBudget.leastAllowance)) s a test needs. Not a pass, and not a skip."
    }

    var errorDescription: String? { description }
}
