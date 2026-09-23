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
Prefer Flutter-native drawing and animation over a video or GIF, and avoid adding
a large dependency for this effect alone. This ticket is visual presentation only:
it must not add API polling or imply that cloud readings are updated continuously.

Depends on the overview screen (#4). Development can use explicitly labelled
sample data before all live energy sources are connected.

## Todo

- [ ] Create a reusable lightning icon with configurable size, color and active/static states.
- [ ] Animate a green highlight flowing through the bolt silhouette in a smooth, subtle loop.
- [ ] Integrate it into the overview's solar-production display with readable power labels.
- [ ] Define active, zero-production, loading, unavailable and stale-data states; do not animate missing or stale readings as if production were confirmed.
- [ ] Keep sample mode clearly labelled and do not let animation speed imply an unverified power value or refresh rate.
- [ ] Respect the platform's reduced-motion/disabled-animation setting with a static fallback; do not communicate status through color or motion alone.
- [ ] Pause animation when offscreen or when the app is inactive, and avoid unnecessary rebuilds or extra network requests.
- [ ] Verify the animation and static fallback on Android, iOS and the browser preview, including small screens and larger text.
- [ ] Add tests for animation state, reduced motion and lifecycle behavior, plus a visual example for review using sample data.
