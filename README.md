<img src="https://ptsochantaris.github.io/trailer/MaintiniLogo.webp" alt="Logo" width=256 align="right">

# Maintini

A friendly and efficient wrapper for wrapping operations so that:
- iOS: Keep the app active for a short time when backgrounded.
- macOS: Ask the system not to go into idle sleep if possible.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fptsochantaris%2Fmaintini%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ptsochantaris/maintini) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fptsochantaris%2Fmaintini%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ptsochantaris/maintini)

Currently used in
- [Trailer](https://github.com/ptsochantaris/trailer)
- [Gladys](https://github.com/ptsochantaris/gladys)
- [Mima](https://github.com/ptsochantaris/mima)

Detailed docs [can be found here](https://swiftpackageindex.com/ptsochantaris/maintini/documentation)

## Overview

- Calls can be nested around any critical section, and Maintini only calls out to the OS task APIs if needed, so these calls are very cheap.
- Maintini will keep the OS from suspending the app, or sleeping, as long as possible if there is at least one session present.
- If the last session exits on iOS, and the app is in the background, it will be suspended a couple of seconds later.
- iOS places a hard limit on the amount of time allowed, and the app will be suspended at the end of that period no matter what. Completing API calls, short data transfers, or sync operations are the kind of thing Maintini is designed for. For longer running operations please refer to Apple's Background Task scheduling API instead.

```
Maintini.setup() // Always call this at app launch to set things up
...

func anExampleWithABlockCall() async {
    await Maintini.maintain {
        await processingThatShouldNotBeInterrupted()
    }
}

func anExampleWithADeferredCall() async {
    Maintini.startMaintaining()
    defer {
        Maintini.endMaintaining()
    }
    await processingThatShouldNotBeInterrupted()
}

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

## License
Copyright (c) 2023 Paul Tsochantaris. Licensed under the MIT License, see LICENSE for details.
