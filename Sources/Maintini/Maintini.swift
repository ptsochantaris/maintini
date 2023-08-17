#if os(macOS)
    import Foundation

    @MainActor
    public enum Maintini {
        public static func maintain(block _: () -> Void) {}
        public static func startMaintaining() {}
        public static func stopMaintaining() {}
    }
#else
    import Combine
    import UIKit

    @MainActor
    public enum Maintini {

        public static func maintain(block: () -> Void) {
            startMaintaining()
            block()
            stopMaintaining()
        }

        public static func startMaintaining() {
            unPush()
            let count = globalBackgroundCount
            globalBackgroundCount = count + 1
            if appInBackground, bgTask == .invalid, count == 0 {
                appBackgrounded()
            }
        }

        public static func stopMaintaining() {
            globalBackgroundCount -= 1
            if globalBackgroundCount == 0, bgTask != .invalid {
                push()
            }
        }

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

        private static var observerTask: Task<Void, Never> = Task {
            let nc = NotificationCenter.default
            Task {
                for await _ in nc.notifications(named: UIApplication.willEnterForegroundNotification) {
                    unPush()
                    appInBackground = false
                    endTask()
                }
            }
            Task {
                for await _ in nc.notifications(named: UIApplication.didEnterBackgroundNotification) {
                    appBackgrounded()
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
