## Purpose

Make energy activity easier to understand and give the overview a polished feel
with subtle animated icons, starting with green energy flowing through a
lightning-bolt symbol.

## Description

Create a reusable animated energy icon for the solar-production overview. A soft
green highlight should travel through the inside of the lightning-bolt shape in
a smooth loop, rather than flashing or moving the whole icon. Keep the underlying
bolt recognizable throughout the animation.

Start with the lightning icon; keep the implementation reusable for future solar,
battery and household icons without requiring those integrations in this ticket.
Prioritize free, reusable animation libraries and existing assets:

- First evaluate a suitable free lightning/energy animation played with Lottie for
  Flutter. Check that it supports the desired green flow, recoloring, looping and
  static states. Bundle the selected asset locally instead of loading it remotely.
- If no suitable asset is available, evaluate `flutter_animate` shimmer/color
  effects on an existing icon. Confirm that the effect stays inside the bolt.
- Use custom Flutter drawing/animation only if these options cannot achieve the
  required effect with reasonable performance and accessibility. Record why.

The selected library and asset must be free to use in this app, with no paid
export or runtime subscription required. Verify each asset's license separately
from the library's license, including permission to modify and redistribute it in
this public repository. Record its source and creator, retain license notices,
and provide any required attribution. Do not assume every marketplace asset is
free. Compare dependency size and rendering cost before choosing an approach.

References: [Lottie for Flutter](https://pub.dev/packages/lottie),
[free lightning animations](https://lottiefiles.com/free-animations/lightning),
[LottieFiles license](https://lottiefiles.com/page/license), and
[`flutter_animate`](https://pub.dev/packages/flutter_animate).

This ticket is visual presentation only: it must not add API polling or imply
that cloud readings are updated continuously.

Depends on the overview screen (#4). Development can use explicitly labelled
sample data before all live energy sources are connected.

## Todo

- [ ] Evaluate free Lottie assets first, then `flutter_animate`; record the selected approach and use custom drawing only as a justified fallback.
- [ ] Verify library and asset licenses, public-repository redistribution rights, modification rights and required attribution; record the source and retain the applicable notices.
- [ ] Confirm there are no required paid exports or subscriptions, and bundle any selected animation asset for offline use.
- [ ] Create a reusable lightning icon with configurable size, color and active/static states.
- [ ] Animate a green highlight flowing through the bolt silhouette in a smooth, subtle loop.
- [ ] Integrate it into the overview's solar-production display with readable power labels.
- [ ] Define active, zero-production, loading, unavailable and stale-data states; do not animate missing or stale readings as if production were confirmed.
- [ ] Keep sample mode clearly labelled and do not let animation speed imply an unverified power value or refresh rate.
- [ ] Respect the platform's reduced-motion/disabled-animation setting with a static fallback; do not communicate status through color or motion alone.
- [ ] Pause animation when offscreen or when the app is inactive, and avoid unnecessary rebuilds or extra network requests.
- [ ] Verify the animation and static fallback on Android, iOS and the browser preview, including small screens and larger text.
- [ ] Add tests for animation state, reduced motion and lifecycle behavior, plus a visual example for review using sample data.
