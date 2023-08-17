# Maintini

Maintain iOS app activity for a short time if needed after the app is backgrounded.

Currently used in
- [Trailer](https://github.com/ptsochantaris/trailer)
- [Gladys](https://github.com/ptsochantaris/gladys)

## Overview

- Calls can be nested around any critical section, and Maintini only calls to the iOS background task API if needed, so these calls are very cheap.
- Maintini will keep the OS from suspending the app as long as possible if there is at least one set of active maintenance active.
- If the last block exits, and the app is in the background, it will be suspended a couple of seconds later.
- iOS will place a hard limit on the amount of time allowed, and the app will be suspended at the end of that period no matter what.

```
Maintini.setup() // Always call this at app launch to set things up

...

func anExampleWithABlockCall() aync {
    await Maintini.maintain {
        await processingThatShouldNotBeInterrupted()
    }
}

func anExampleWithADeferredCall() async {
    await Maintini.startMaintaining()
    defer {
        await Maintini.endMaintaining()
    }
    await processingThatShouldNotBeInterrupted()
}

func anExampleWithNestedCalls() async {
    await Maintini.startMaintaining()

    Task {
        await processingThatShouldNotBeInterrupted()

        await anExampleWithADeferredCall()

        await anExampleWithABlockCall()

        await Maintini.endMaintaining()
    }
}

```

## License
Copyright (c) 2023 Paul Tsochantaris. Licensed under the MIT License, see LICENSE for details.
