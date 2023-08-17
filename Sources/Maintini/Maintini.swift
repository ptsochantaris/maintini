#if os(macOS)
    import Foundation

    @MainActor
    public enum Maintini {
        public static func setup() {}
        public static func maintain(_: () async -> Void) async {}
        public static func startMaintaining() {}
        public static func endMaintaining() {}
    }
#else
    import Combine
    import UIKit

    @MainActor
    public enum Maintini {
        public static func setup() {
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
        }

        public static func maintain(block: () async -> Void) async {
            startMaintaining()
            await block()
            endMaintaining()
        }

        public static func startMaintaining() {
            unPush()
            let count = globalBackgroundCount
            globalBackgroundCount = count + 1
            if appInBackground, bgTask == .invalid, count == 0 {
                appBackgrounded()
            }
        }

        public static func endMaintaining() {
            globalBackgroundCount -= 1
            if globalBackgroundCount == 0, bgTask != .invalid {
                push()
            }
        }

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
    }
#endif
