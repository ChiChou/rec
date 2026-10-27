# Rec

![Badge](https://img.shields.io/badge/AI_Slop-Yes-red)

A small macOS utility for recording product demo videos of a single window, sized for the platform you're posting to.

Everything happens in one window:

1. **Allow Screen Recording** on first launch so rec can list your windows. Allow Accessibility too, so it can resize them.
2. **Pick a window** from the thumbnail grid on the left. Search by app or title.
3. **Pick a video size** on the right: YouTube 4K (3840×2160), YouTube HD (1920×1080), X / Twitter (1280×720), or Reels HD (1080×1920) for TikTok, Instagram Reels and YouTube Shorts.
4. **Check the preview.** It shows the video frame live, as it would look if you started recording now. A badge says whether the window already fits, will be resized when recording starts, or will be cropped or letterboxed. **Fit** resizes the window right away.
5. **Record** (or press Return). rec's window steps aside, and the target window is resized and brought to the front. A countdown badge appears over the target window, then a small floating bar with the timer and a Stop button. Neither is captured, because rec records only the target app. It records the area of the target window and shows only that app's windows in it, so its menus, sheets and dialogs are in the video and the recording keeps going when the app swaps windows. Keep the window where it is while recording; the area is fixed when recording starts.
6. **Stop.** rec comes back with the new recording ready to play or show in Finder. Files are saved to `~/Movies/Rec/`.

With **2× Retina** on (the default), one window point becomes two video pixels, so 1080p needs a 960×540 pt window and the UI looks large and sharp. With it off, one point becomes one pixel, so the window is twice as large and more of the app fits in the frame. If the window doesn't fit on screen, rec uses the largest size with the same aspect ratio that does.

Some apps won't resize to every shape. For example, a window with a 1000 pt minimum width can't be 9:16 on a laptop screen. rec first tries to stretch the other side to restore the shape. If that doesn't fit on screen, the countdown badge shows a warning and a Cancel button, and the countdown keeps going unless you cancel. With **Crop to fill** on (the default), rec records a centered slice of the window in the target shape; with it off, the video gets black bars.

## Requirements

macOS 15 or later (uses ScreenCaptureKit's `SCRecordingOutput`).

## Troubleshooting

If a recording stops early, rec says so in its window, keeps what was recorded, and logs the reason to `~/Library/Logs/Rec/rec.log` (and the unified log, subsystem `me.chichou.rec`).

## Build

```sh
./scripts/bundle.sh                                   # ad-hoc signed build/Rec.app
CODESIGN_IDENTITY="Apple Development: …" ./scripts/bundle.sh   # keeps permissions across rebuilds
swift test
```
