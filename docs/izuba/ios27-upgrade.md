# Stray Scanner Izuba 1.0 (1): iOS 27 upgrade report

Fork of https://github.com/strayrobots/scanner at `ec3e1dc` (4 April 2026), MIT licence kept in `LICENSE.md`.
Branch `izuba/ios27`. Built on 25 September 2026 with Xcode 27.0 (27A266a, licence GM) at `/Applications/Xcode.app`.

## Starting point

- Swift 5, UIKit shell with SwiftUI screens, Core Data, Metal, a C/C++ PNG encoder (lodepng).
- CocoaPods with an empty Podfile. The committed Pods project set iOS 14.2, which Xcode 27 refuses:
  `The iOS Simulator deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 14.2, but the range of supported deployment target versions is 15.0 to 27.0.x.`
- The app icons are stored with Git LFS. A clone without `git lfs pull` fails in actool: `The ... app icon set ... named "AppIcon" did not have any applicable content.`
- `armv7` in `UIRequiredDeviceCapabilities`. App Store Connect rejects this for an arm64 build.
- Upstream team and bundle ids, version 1.4.

## What changed

| Area | Change |
|---|---|
| Dependencies | CocoaPods removed: Podfile, lock, Pods/, workspace, the manifest-check build phases and xcconfigs. Open `StrayScanner.xcodeproj` directly. |
| Toolchain | iOS 26.0 minimum on every target. Swift 6 language mode. C++20, C17. Dead-code stripping, script sandboxing. |
| Identity | `com.izuba.strayscanner` (app), `.debug`, `.tests`. Team N9PH82KMF2. Version 1.0 (1). "Apple Development" signing. |
| Info.plist | `arm64` replaces `armv7`. `ITSAppUsesNonExemptEncryption = NO` (CryptoKit only hashes a folder name). Clearer camera purpose string. |
| Privacy | `PrivacyInfo.xcprivacy`: no tracking, no collected data. UserDefaults `CA92.1` (fps setting). System boot time `35F9.1` (`systemUptime` in `VideoEncoder`). |
| SwiftUI | `NavigationStack`, `@FetchRequest` instead of a view model with a notification, `dismiss`, `foregroundStyle`, `ignoresSafeArea`, `Link`, `#Preview`, no `UIScreen.main`. |
| App | `@main`. The recorder saves on the main-queue view context. It used to save a background context from the main thread. |
| Concurrency | ARKit delegate conformance is `@preconcurrency`. IMU handlers are `@Sendable` and capture the encoder, not the controller. `DatasetEncoder` and `VideoEncoder` are `@unchecked Sendable`, with the threading written above them. |
| IMU | The IMU queue is serial. Accelerometer and gyroscope used to race on one shared buffer. The queue is drained before `imu.csv` is closed. |
| Report | New: `DatasetReport` reads a dataset folder back from disk. `RecordingReportView` shows it under each recording's video. |
| About | Origin of this build, version, the transfer steps, the dataset format and the report. |
| Tests | The stale test used `NPYArrayWrapper`, which no longer exists. It is replaced by two report tests on a synthetic dataset. |

The dataset format is unchanged. The files, names, columns, resolutions and encodings are exactly those of `docs/format.md`.

## The report

For each recording, read on a background task when the detail screen opens:

- Frames: video frames (compressed samples counted with `AVAssetReader`, nothing decoded), depth maps, confidence maps and poses. Whether they agree within 2. Frames per second.
- Depth of the middle frame: resolution and bit depth, nearest, median and farthest depth in metres, and the share of valid pixels.
- Confidence of the same frame: the share of high, medium and low. Any value outside {0, 1, 2} is shown.
- Camera: video size, focal length and principal point from `odometry.csv`, whether the camera matrix and lens distortion tables are present.
- Motion: IMU samples and their rate.
- Storage: size on disk and folder name.

## Proof

| Check | Result | Log |
|---|---|---|
| Simulator build, Debug, generic iOS Simulator | `** BUILD SUCCEEDED **`, 0 compiler warnings | `vendor/build-sim5.log` |
| Unit tests, iPhone 17 Pro simulator, iOS 27.0 | `** TEST SUCCEEDED **`, 2 tests, 0 failures | `vendor/test-sim.log` |
| Device build, Release, generic iOS, clean | `** BUILD SUCCEEDED **`, 0 warnings, signed N9PH82KMF2 | `vendor/build-device.log` |
| `StrayScanner debug` target, simulator | `** BUILD SUCCEEDED **` | `vendor/build-debugtarget.log` |

The signed bundle reads `com.izuba.strayscanner` 1.0 (1), MinimumOSVersion 26.0, SDK iphoneos27.0, arm64. Its profile lists the iPhone 17 Pro `00008150-000110AC0E68C01C`.

## Not proven here

- A recording on the device with this build, and the report on real data. The simulator has no LiDAR.
- An archive. See `docs/acceptance/pre-archive-1.0.md`.
