import Combine
import Foundation
#if !(os(macOS) || os(watchOS))
    import UIKit
#endif

/// An instance of `Maintini`.
@MainActor
public enum Maintini {
    /// Always call this at iOS app launch to set things up, as `Maintini` needs to listen to app foregrounding or backgrounding notifications. Recommended place for this call is in `appDidFinishLaunching`. On macOS this is a no-op.
    ///
    /// ```
    /// Maintini.setup()
    /// ```
    public static func setup() {
        #if !(os(macOS) || os(watchOS))
            if foregroundObserver == nil {
                foregroundObserver = NotificationCenter.default
                    .publisher(for: UIApplication.willEnterForegroundNotification)
                    .sink { _ in
                        unPush()
                        appInBackground = false
                        endTask()
                    }
            }
            if backgroundObserver == nil {
                backgroundObserver = NotificationCenter.default
                    .publisher(for: UIApplication.didEnterBackgroundNotification)
                    .sink { _ in
                        appBackgrounded()
                    }
            }
        #endif
    }

    /// Protect the app from being suspended in the background while the code in the block is executing.
    /// - Parameter block: The code to execute.
    ///
    /// ```
    /// func anExampleWithABlockCall() async {
    ///    await Maintini.maintain {
    ///        await processingThatShouldNotBeInterrupted()
    ///    }
    /// }
    /// ```
    /// On iOS-flavoured platforms the code in this block must not have a long execution time or else the OS will suspend the app anyway.
    ///
    /// This call can be made while the app is in the background due to other calls to `Maintini`: The app will try to stay active until the last maintini session has finished.
    ///
    /// Repeated parallel or nested calls are possible, but do note that they will not extend the app's maximum lifetime while in the background.
    public static func maintain(block: () async -> Void) async {
        startMaintaining()
        await block()
        endMaintaining()
    }

    /// Signal that from this point on, if needed, the app should stay active if put into the foreground, as long as iOS will allow. On macOS the system will not go into idle sleep while this is active, as long as user settings permit that.
    ///
    /// ```
    /// func anExampleWithADeferredCall() async {
    ///     await Maintini.startMaintaining()
    ///     defer {
    ///         Task { await Maintini.endMaintaining() }
    ///     }
    ///     await processingThatShouldNotBeInterrupted()
    /// }
    /// ```
    /// All calls to this method _must_ be balanced with a call to ``endMaintaining()`` at some later point, or else `Maintini` will not work correctly.
    ///
    /// On iOS-flavoured platforms the time period between this call and that one must not be long or else the OS will suspend the app anyway.
    ///
    /// This call can be made while the app is in the background as a consequence to other calls to `Maintini`: The effect will persist until the last `Maintini` session has finished.
    ///
    /// Repeated parallel start/end sessions are possible, but do note that, on iOS, they will not extend the app's maximum lifetime while in the background.
    public static func startMaintaining() {
        #if !os(watchOS)
            unPush()
            let count = activityCount
            activityCount = count + 1
            if count == 0, !bgTask.isActive {
                #if os(macOS)
                    let task = ProcessInfo.processInfo.beginActivity(reason: "Maintini \(UUID().uuidString)")
                    bgTask = .active(task)
                #elseif os(iOS)
                    if appInBackground {
                        appBackgrounded()
                    }
                #endif
            }
        #endif
    }

    /// Signal that whatever task needed the app to stay active is done now.
    ///
    /// `Maintini` will start a two second countdown and if there are no other background tasks it will allow the app to be suspended in the background. On macOS this tells the system that it can sleep if it wants to.
    ///
    /// Please note that it is possible that, on iOS-flavoured platforms, the OS can suspend the app even before this method is called, if the app takes too long to call this method. In this case a call to this method _must still be made_ regardless.
    ///
    /// Start and end calls must always balance out. Consider using a `defer` block for safety, or the `Maintini` block syntax variant ``maintain(block:)``.
    public static func endMaintaining() {
        #if !os(watchOS)
            activityCount -= 1
            if activityCount == 0, bgTask.isActive {
                push()
            }
        #endif
    }

    #if !os(watchOS)
        private enum State {
            #if os(macOS)
                case active(NSObjectProtocol)
            #elseif os(iOS)
                case active(UIBackgroundTaskIdentifier)
            #endif
            case inactive

            var isActive: Bool {
                switch self {
                case .active:
                    return true
                case .inactive:
                    return false
                }
            }
        }

        private static var bgTask = State.inactive
        private static var activityCount = 0
        private static var cancel: Cancellable?
        private static let publisher = PassthroughSubject<Void, Never>()

        private static func endTask() {
            switch bgTask {
            case .inactive:
                return
            case let .active(task):
                unPush()
                bgTask = .inactive
                #if os(macOS)
                    ProcessInfo.processInfo.endActivity(task)
                #elseif os(iOS)
                    UIApplication.shared.endBackgroundTask(task)
                #endif
            }
        }

        private static func push() {
            if cancel == nil {
                let stride = RunLoop.SchedulerTimeType.Stride(3)
                cancel = publisher.debounce(for: stride, scheduler: RunLoop.main).sink { _ in
                    cancel = nil
                    endTask()
                }
            }
            publisher.send()
        }

        private static func unPush() {
            cancel?.cancel()
            cancel = nil
        }

        #if !os(macOS)
            private static var foregroundObserver: Cancellable?
            private static var backgroundObserver: Cancellable?
            private static var appInBackground = UIApplication.shared.applicationState == .background

            private static func appBackgrounded() {
                appInBackground = true
                if activityCount != 0, !bgTask.isActive {
                    // log("BG Task starting")
                    let task = UIApplication.shared.beginBackgroundTask {
                        endTask()
                    }
                    bgTask = .active(task)
                }
            }
        #endif
    #endif
}
