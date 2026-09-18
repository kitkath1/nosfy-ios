import Foundation

protocol ActivityAttributes {
    associatedtype ContentState: Codable & Hashable
}
struct ActivityContent<State> { var state: State; var staleDate: Date? }
enum ActivityState { case active, stale, ended, dismissed }
enum ActivityUIDismissalPolicy { case immediate }

@MainActor enum Probe {
    static var activities: [AnyObject] = []
    static var enabled = true
    static var blockNextUpdate = false
    static var suspendedUpdate: CheckedContinuation<Void, Never>?
}
@MainActor struct ActivityAuthorizationInfo {
    var areActivitiesEnabled: Bool { Probe.enabled }
}
@MainActor final class Activity<Attributes: ActivityAttributes> {
    let id = UUID().uuidString
    let attributes: Attributes
    var content: ActivityContent<Attributes.ContentState>
    var activityState = ActivityState.active
    var updateCalls = 0
    var endCalls = 0
    var immediate = false
    static var activities: [Activity] { Probe.activities.compactMap { $0 as? Activity } }
    init(attributes: Attributes, content: ActivityContent<Attributes.ContentState>) {
        self.attributes = attributes
        self.content = content
    }
    static func request(attributes: Attributes,
                        content: ActivityContent<Attributes.ContentState>) throws -> Activity {
        let activity = Activity(attributes: attributes, content: content)
        Probe.activities.append(activity)
        return activity
    }
    func update(_ content: ActivityContent<Attributes.ContentState>) async {
        updateCalls += 1
        if Probe.blockNextUpdate {
            Probe.blockNextUpdate = false
            await withCheckedContinuation { Probe.suspendedUpdate = $0 }
        }
        self.content = content
    }
    func end(_ content: ActivityContent<Attributes.ContentState>?,
             dismissalPolicy: ActivityUIDismissalPolicy) async {
        endCalls += 1
        immediate = dismissalPolicy == .immediate
        activityState = .ended
    }
}
@MainActor final class Workout {
    let startedAt: Date
    var isActive = true
    var exerciseCount = 1
    var setCount = 1
    var seriesPayantes = 1
    var totalVolume = 20.0
    init(_ timestamp: TimeInterval) { startedAt = Date(timeIntervalSince1970: timestamp) }
}
enum Langue { static var courante: String { "fr" } }

@main struct ControllerChecks {
    @MainActor static var assertions = 0
    @MainActor static func check(_ condition: @autoclosure () -> Bool, _ label: String) {
        precondition(condition(), label)
        assertions += 1
    }
    @MainActor static func until(_ label: String, _ condition: () -> Bool) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        fatalError("Timeout: \(label)")
    }
    @MainActor static func drain() async {
        for _ in 0..<100 { await Task.yield() }
    }
    @MainActor static func main() async {
        let first = Workout(1_800_000_001)
        WorkoutActivityController.ensure(first)
        let activity = Activity<WorkoutActivityAttributes>.activities[0]
        check(activity.activityState == .active, "activity requested")
        let source = UUID()
        var focus = WorkoutLiveFocus(source: source, exerciseID: "hiit-tapis", name: "HIIT",
                                     sport: .hiit, phase: .init(kind: .effort, startedAt: first.startedAt),
                                     set: 1, value: 12)
        WorkoutActivityController.show(focus, for: first)
        await until("focus published") { activity.content.state.focus != nil }
        check(activity.content.state.focus?.source == source, "actual controller publishes focus")

        Probe.blockNextUpdate = true
        focus.phase = .init(kind: .recovery, startedAt: first.startedAt + 40)
        WorkoutActivityController.show(focus, for: first)
        await until("in-flight update blocked") { Probe.suspendedUpdate != nil }
        focus.phase = .init(kind: .effort, startedAt: first.startedAt + 60)
        WorkoutActivityController.show(focus, for: first)
        WorkoutActivityController.end()
        await until("Stop bypasses blocked update") { activity.activityState == .ended }
        check(Probe.suspendedUpdate != nil, "Stop did not wait for pending update")
        check(activity.immediate, "Stop requests immediate removal")

        let count = Probe.activities.count
        WorkoutActivityController.ensure(first)
        WorkoutActivityController.show(focus, for: first)
        WorkoutActivityController.sync(first)
        check(Probe.activities.count == count, "late callback cannot recreate cancelled session")

        let second = Workout(1_800_000_101)
        WorkoutActivityController.ensure(second)
        let next = Activity<WorkoutActivityAttributes>.activities.last!
        check(next.id != activity.id, "new session starts")
        check(next.content.state.focus == nil, "new session has no stale exercise focus")
        Probe.suspendedUpdate?.resume()
        Probe.suspendedUpdate = nil
        await drain()
        check(activity.updateCalls == 2, "queued updates skipped after Stop")
        check(activity.activityState == .ended, "in-flight completion cannot reactivate activity")
        check(next.activityState == .active, "old Stop does not close new session")

        first.isActive = false
        WorkoutActivityController.ensure(first)
        WorkoutActivityController.sync(first)
        WorkoutActivityController.show(focus, for: first)
        await drain()
        check(next.activityState == .active, "late closed workout cannot close new session")
        next.activityState = .dismissed
        WorkoutActivityController.ensure(second)
        check(Probe.activities.count == count + 1, "dismissed activity stays dismissed")

        let third = Workout(1_800_000_201)
        WorkoutActivityController.ensure(third)
        let last = Activity<WorkoutActivityAttributes>.activities.last!
        WorkoutActivityController.ensure(nil)
        await until("no active workout closes activity") { last.activityState == .ended }
        check(last.immediate, "no active workout removes banner immediately")
        WorkoutActivityController.ensure(third)
        check(Probe.activities.count == count + 2, "cleared workout cannot reopen")
        let closed = Workout(1_800_000_301)
        closed.isActive = false
        WorkoutActivityController.ensure(closed)
        check(Probe.activities.count == count + 2, "closed workout is never requested")
        WorkoutActivityController.end()
        await drain()
        check(last.endCalls == 1, "Stop is idempotent once ended")
        print("PASS \(assertions) controller checks; blocked update, Stop, late callbacks and new session exercised")
    }
}
