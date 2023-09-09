import Combine
import Foundation
#if !(os(macOS) || os(watchOS))
    import UIKit
#endif

/// An instance of `Maintini`. Note that on macOS all calls are no-ops.
@MainActor
public enum Maintini {
    /// Always call this at app launch to set things up, as `Maintini` needs to listen to app foregrounding or backgrounding notifications. Recommended place for this call is in `appDidFinishLaunching`
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
    /// The code in this block must not have a long execution time or else iOS will suspend the app anyway.
    ///
    /// This call can be made while the app is in the background due to other calls to `Maintini`: The app will try to stay active until the last maintini session has finished.
    ///
    /// Repeated parallel or nested calls are possible, but do note that they will not extend the app's maximum lifetime while in the background.
    public static func maintain(block: () async -> Void) async {
        startMaintaining()
        await block()
        endMaintaining()
    }

    /// Signal that from this point on, if needed, the app should stay active if put into the foreground, as long as iOS will allow.
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
    /// The time period between this call and that one must not be long or else iOS will suspend the app anyway.
    ///
    /// This call can be made while the app is in the background due to other calls to `Maintini`: The app will try to stay active until the last `Maintini` session has finished.
    ///
    /// Repeated parallel start/end sessions are possible, but do note that they will not extend the app's maximum lifetime while in the background.
    public static func startMaintaining() {
        #if !(os(macOS) || os(watchOS))
            unPush()
            let count = globalBackgroundCount
            globalBackgroundCount = count + 1
            if appInBackground, bgTask == .invalid, count == 0 {
                appBackgrounded()
            }
        #endif
    }

    /// Signal that whatever task needed the app to stay active is done now.
    ///
    /// `Maintini` will start a two second countdown and if there are no other background tasks it will allow the app to be suspended.
    ///
    /// Please note that it is possible that iOS will suspend the app even before this method is called, if the app takes too long to call this method. In this case a call to this method _must still be made_ regardless.
    ///
    /// Start and end calls must always balance out. Consider using a `defer` block for safety, or the `Maintini` block syntax.
    public static func endMaintaining() {
        #if !(os(macOS) || os(watchOS))
            globalBackgroundCount -= 1
            if globalBackgroundCount == 0, bgTask != .invalid {
                push()
            }
        #endif
    }

    #if !(os(macOS) || os(watchOS))
        private static var foregroundObserver: Cancellable?
        private static var backgroundObserver: Cancellable?
        private static var bgTask = UIBackgroundTaskIdentifier.invalid
        private static var globalBackgroundCount = 0
        private static var appInBackground = UIApplication.shared.applicationState == .background
        private static let publisher = PassthroughSubject<Void, Never>()
        private static var cancel: Cancellable?

        private static func appBackgrounded() {
            appInBackground = true
            if globalBackgroundCount != 0, bgTask == .invalid {
                // log("BG Task starting")
                bgTask = UIApplication.shared.beginBackgroundTask {
                    endTask()
                }
            }
        }

        private static func endTask() {
            if bgTask == .invalid { return }
            // log("BG Task done")
            unPush()
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
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
    #endif
}
