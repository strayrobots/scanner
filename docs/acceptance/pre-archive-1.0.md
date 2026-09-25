# Pre-archive record, Stray Scanner Izuba 1.0 (1)

Run on 25 September 2026, branch `izuba/ios27`, code commit `793e232`.
Command: `~/.claude/skills/ios-release-preflight/scripts/preflight.sh --check-only --app ../DerivedData/Build/Products/Release-iphoneos/StrayScanner.app`.
`git status --porcelain` was byte-identical before and after the run.

## Checks

| # | Check | Result | Note |
|---|---|---|---|
| 1 | Toolchain | FAIL, false positive | Only one Xcode on this Mac: 27.0 (27A266a), `LicenseInfo.plist` licenceType `GM`. The script calls any build ending in a letter a beta; Xcode 16.0 was 16A242d. Franck confirms before the upload. |
| 2 | Git | FAIL before the tag | Tag `v1.0.0-build1` is created on the commit carrying this record. |
| 3 | Versions | FAIL, not applicable | The script expects xcodegen `project.yml`. This project has none. Versions live in the target build settings (1.0, 1), and the app Info.plist references them. The test bundle plist has literal values; it never ships. |
| 4 | Entitlements | OK | From the signed Release bundle: application-identifier `N9PH82KMF2.com.izuba.strayscanner`, no iCloud, no push, no app group. |
| 5 | Stray files | OK | None in `StrayScanner.app`. |
| 6 | Markers | WARN, accepted P3 | 42 `print(` calls, all from upstream logging. Owner Franck, reason: diagnostics only, no user data. |
| 7 | Encryption | OK | `ITSAppUsesNonExemptEncryption = NO`. |
| 8 | Privacy manifest | OK, present and verified | UserDefaults `CA92.1`, system boot time `35F9.1`. `contentsOfDirectory` reads names only, no timestamps. No file timestamp, disk space or active keyboard API in the sources, the C code included. No third-party code. |
| 9 | StoreKit | OK | No purchases. |
| 10 | Screenshots | WARN, not applicable yet | Internal TestFlight needs none. External testing and the store need a set. |

Verdict: archive, once Franck confirms check 1.

## Not covered by this check

- The archive itself. Only an archive proves an archive.
- The install and a recording on the iPhone 17 Pro with this build.
- The App Store Connect record: name "Stray Scanner Izuba", bundle id `com.izuba.strayscanner`, SKU. Franck creates it.
- The TestFlight walkthrough on the device. There is no previous version, so there is no upgrade path to test.
- External TestFlight review, which needs a description, a contact and a privacy policy URL.

## Archive command, Franck's to run (not run here)

```bash
cd ~/Projects/venturing/vendor/scanner && git checkout v1.0.0-build1 && \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project StrayScanner.xcodeproj -scheme StrayScanner -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath /tmp/StrayScannerIzuba-1.0-1.xcarchive \
    -derivedDataPath ../DerivedData-archive \
    -allowProvisioningUpdates archive 2>&1 \
    | grep -E 'error:|ARCHIVE (SUCCEEDED|FAILED)'
```

Then Xcode > Window > Organizer > Archives > Distribute App > App Store Connect > Upload.
