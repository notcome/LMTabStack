# ``LMTabStack``

LMTabStack is a pure SwiftUI container that supports multiple tabs of navigation stacks with customizable layouts, fully native page transitions, and hybrid rendering for smoother animations.

## Overview

LMTabStack offers complete flexibility in defining custom layouts, freeing you from fixed layouts such as full-page navigation stacks or split-screen master-detail views. Built on SwiftUI’s custom container API, it provides a natural and type-safe way to declare pages in a stack, allowing you to model navigation states naturally, without relying on a mutable navigation stack.

The container is implemented entirely in SwiftUI, avoiding the complexity of bridging to UIKit or AppKit. It supports fully customizable page transitions, such as morphing elements across pages and defining multiple tracks with independent timing functions, offering unparalleled control over animation dynamics. Gesture-driven interactive transitions are seamlessly supported.

Finally, LMTabStack includes a hybrid rendering mode that offloads certain transitions to CAAnimation. This approach bypasses the 60Hz animation limit in SwiftUI on iPhones, even with ProMotion, enabling smoother and more dynamic animations.


## How It Works

- SwiftUI’s [custom container APIs](https://developer.apple.com/videos/play/wwdc2024/10146/) allow us to transform a two-level view hierarchy, while taking care of binding environment values.
- We map each section to a tab, and each child of a section a page in the navigation stack for that view.
- A user-provided ``TabStackLayout`` computes each page’s visibility, its frames, z-index, and its safe area.
- We store the layout in our main model object. A sibling to the above *view generator*, which we call a *view presenter*, listens to the model, and actually present them in a `ZStack`.
- We observe changes to the view generator’s output, along with the change’s corresponding transaction, to determine if an animated/interactive transition is needed. This observation is done via an empty `UIViewRepresentable`/`NSViewRepresentable`, which handily provides the context for an update.
- When a transition is needed, we update the model to include a resolved ``AdvancedTransition``. Then, a sibling to the view generator/presenter, which we call the *transition generator*, would abuse the custom container API again to obtain all changes in the transition.
- Here, we map each section to a *track* with its own animation timing, which will be used for each change in that track. For instance, position/size changes are best animated with spring animations, whereas opacity changes for “view morphing” can use ease in/out.
- Similar to the bottom of the view generator sending views to display to the model, the bottom of the transition generator sending transitions to the model. The view presenter, by virtue of listening to the model, is the receiving end of the update flow. Hence, we have an unidirectional information flow, avoiding the concern for cyclic updates.
- Due to the inherent statefulness of our implementation, care is taken to ensure that our system moves to a particular state before we move on. For instance, we use anchor preferences to report each page’s frame, and only when that preference value is stored in our model do we consider the page is loaded. Crucially, we do not perform transition generator until all appearing pages have loaded.
- For animated but non-interactive transitions, we first move the transition state to ``TransitionProgress.start``. Only when each transitioning page has submitted their transient values for the start state, do we update that value to ``TransitionProgress.end``. Then, we update our transition model tree where each track’s changes are animated using independent transactions with desired animations.
- Interactive transitions are similar. The only difference is that once started, interactive transitions can be updated, and at the end of the interaction (e.g. the end of a gesture), the transition is marked as completed, with animation, and can be updated no more.
- Animations can be described in two ways, transition effects and transition values.
- Transition effects are a limited set of common visual effects. They include:
    - Blur radius.
    - Opacity.
    - Offset and scale.
    - An optional mask’s size and corner radius. More on them later.
- Transition effects can be rendered to `CAAnimation`, this enables 120Hz animation on iPhone with ProMotion displays. Pure SwiftUI animations cannot do that.
- Transition values are similar to SwiftUI’s environment where you can add custom properties. The only difference is that they are only “active” during a transition, and give the default value when idle.
- Care has been taken in the implementation of the ``TransitionValues`` type. It is a value type that plays well with Swift’s observation mechanism and SwiftUI’s animation system. You can read the value in your SwiftUI view via the ``TransitionValue`` property wrapper.
- Animations can be applied to four types of views:
    - Page content.
    - Page wrapper.
    - Morphing views for a page.
    - Transition elements within a page.
- Morphing views are transient views that only live during a transition. In fact, you declare them via ``AdvancedTransition.morphingViews`` method. They live inside the page wrapper, and are siblings to the page content. That’s why we have the distinction between the two.
- Transition elements are views inside that page that can be animated independently. For instance, if you want a button in the disappearing page to morph into another button in the appearing page, you can do it in three steps. First, you mark both buttons as transition elements. Second, during the transition, set the opacity of both buttons to zero. Third, create a morphing view that starts at the first button’s position and ends at the second button’s. Notice that, when combined with transition values, you can use very complex SwiftUI animations for button morphing.
- Morphing views are in pure SwiftUI, and resizing them does not play well with Core Animation. As a result, if you need to morph a background from one size to another at 120Hz, you need transition effects’s masking animation.
- Transition values apply to the whole page. You can have different transition values for different pages, but they must stay the same for everything in one page, including that page’s morphing views and transition elements.
- To use Core Animation for transition effects, you can set the rendering mode to hybrid. In that case, pages you declared will be rendered using a hosting controller, whereas morphing views and transition elements will be rendered using a hosting view. We use a custom transaction key to record the animation timing for each change, and create the corresponding animations using `Core Animation`.
- Since the rendering mode is controlled by an environment key, you can set it inside your page to make some or all of your transition elements to be rendered by pure SwiftUI. This may or may not impact your performance.
- We also implemented a simple velocity tracking system (by approximating from the last two samples). If you use a spring animation, you can get the correct initial velocity, regardless you render it via SwiftUI or Core Animation.
- Remember, all above hybrid animation discussion applies only to changes to transition effects. Changes to transition values are not included.
- Pages that do not belong to any tabs are treated as decorations. They can be used to implement a tab bar, or the floating player in Apple Music.
- You can specify your transition in four ways:
    - You can provide a transition provider to your ``TabStackView``. This is similar to the delegate for a `UINavigationController`.
    - You can attach a transition providier to any tabs. They will only be used if all changes to page placements are in to that particular tab. Notice that changes to decoration views does not affect the provider’s eligibility, and you can still handle changes to those decoration views in your transition.
    - You can attach a transition provider to any page. They will only be used if that page is appearing or disappearing. Other changing pages can come from anywhere, including other tabs. This feature make its power *not* a strict subset of the tab-level transition provider.

        You can apply more than one transition providers at either tab-level or page-level. They will be attempted in order. You however cannot do the same for the top-level transition provider.
    - You can also set the transition directly in the transaction that applies the change. This gives you the ultimate precise control. While it is handy and direct in some cases, it is often more verbose, and you may often forget some edge cases where a tiny binding would trigger a transition. Therefore, use it with caution.
- For interactive transitions, use ``TransitionInteraction`` property wrapper instead.


