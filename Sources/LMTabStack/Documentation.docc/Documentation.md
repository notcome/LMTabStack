# ``LMTabStack``

LMTabStack is a pure SwiftUI container that supports multiple tabs of navigation stacks with customizable layouts, fully native page transitions, and hybrid rendering for smoother animations.

## Overview

LMTabStack offers complete flexibility in defining custom layouts, freeing you from fixed layouts such as full-page navigation stacks or split-screen master-detail views. Built on SwiftUI’s custom container API, it provides a natural and type-safe way to declare pages in a stack, allowing you to model navigation states naturally, without relying on a mutable navigation stack.

The container is implemented entirely in SwiftUI, avoiding the complexity of bridging to UIKit or AppKit. It supports fully customizable page transitions, such as morphing elements across pages and defining multiple tracks with independent timing functions, offering unparalleled control over animation dynamics. Gesture-driven interactive transitions are seamlessly supported.

Finally, LMTabStack includes a hybrid rendering mode that offloads certain transitions to CAAnimation. This approach bypasses the 60Hz animation limit in SwiftUI on iPhones, even with ProMotion, enabling smoother and more dynamic animations.
