# ``Maintini``

A friendly and efficient wrapper to protect iOS app operations for a short time when backgrounded

## Overview

- Calls can be nested around any critical section, and Maintini only calls out to the iOS background task API if needed, so these calls are very cheap.
- Maintini will keep the OS from suspending the app as long as possible if there is at least one activity maintenance session.
- If the last session exits, and the app is in the background, it will be suspended a couple of seconds later.
- iOS places a hard limit on the amount of time allowed, and the app will be suspended at the end of that period no matter what. Completing API calls, short data transfers, or sync operations are the kind of thing Maintini is designed for. For longer running operations please refer to Apple's Background Task scheduling API instead.
- Maintini will build on macOS and is safe to use in shared code, but all calls to it on macOS build will be no-ops.

```
func anExampleWithABlockCall() async {
    await Maintini.maintain {
        await processingThatShouldNotBeInterrupted()
    }
}
```
```
func anExampleWithADeferredCall() async {
    Maintini.startMaintaining()
    defer {
        Maintini.endMaintaining()
    }
    await processingThatShouldNotBeInterrupted()
}
```
```
func anExampleWithNestedCalls() async {
    Maintini.startMaintaining()

    Task {
        await processingThatShouldNotBeInterrupted()

        await anExampleWithADeferredCall()

        await anExampleWithABlockCall()

        Maintini.endMaintaining()
    }
}
```

## Topics

### Setup
- ``Maintini/Maintini/setup()``

### Signaling the start and end of a session
- ``Maintini/Maintini/startMaintaining()``
- ``Maintini/Maintini/endMaintaining()``

### Using block syntax
- ``Maintini/Maintini/maintain(block:)``
