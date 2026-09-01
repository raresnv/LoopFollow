# APNs Environment-Aware Credentials Implementation Plan

> Execute this plan in order using red-green-refactor. Do not send any real treatment command during verification.

**Goal:** Let LoopFollow Live Activities use Production APNs credentials while remote commands to an Xcode-installed Loop app use separate Sandbox credentials, even when both apps share a Developer Team ID.

**Architecture:** Add a pure selector that compares both the effective target Team ID and APNs environment. Route Loop and Trio remote senders, settings validation, and settings-field visibility through it. Leave Live Activity and return-notification credential handling unchanged.

**Tech stack:** Swift, SwiftUI, Combine, Swift Testing, Xcode/iOS device tooling.

## Task 1: Add failing selector tests

**Create:** Tests/APNsCredentialSelectorTests.swift

1. Add Swift Testing cases with sentinel credentials, never real private keys:
   - same team/same environment selects LoopFollow credentials;
   - same team/different environment selects Remote credentials;
   - different team/same environment selects Remote credentials;
   - different team/different environment selects Remote credentials;
   - empty Remote Team ID falls back to the LoopFollow Team ID;
   - an environment mismatch still requires Remote credentials when its Team ID is empty;
   - requiresRemoteCredentials agrees with select.
2. Run the focused test on the explicit device:

       xcodebuild -project LoopFollow.xcodeproj \
         -scheme LoopFollow \
         -destination 'id=5976EE99-FF62-5869-AB6A-13577A8A22F6' \
         -derivedDataPath /private/tmp/LoopFollowDerivedData \
         -clonedSourcePackagesDirPath /private/tmp/LoopFollowSourcePackages \
         -only-testing:Tests/APNsCredentialSelectorTests \
         test

3. Confirm RED specifically because APNsCredentialSelector is missing, not because of signing, dependencies, or device state.
4. Commit the test:

       git add Tests/APNsCredentialSelectorTests.swift
       git commit -m "test: cover APNs credential environment selection"

## Task 2: Implement the pure selector

**Create:** LoopFollow/Remote/APNsCredentialSelector.swift  
**Test:** Tests/APNsCredentialSelectorTests.swift

1. Define an internal APNsCredentials value with apnsKey, keyId, and teamId.
2. Define pure APNsCredentialSelector functions that:
   - use the Remote Team ID when present and otherwise fall back to the LoopFollow Team ID;
   - require Remote credentials when the effective target Team ID or environment differs;
   - return Remote credentials when separate credentials are required and LoopFollow credentials otherwise.
3. Do not reference Storage, BuildDetails, logging, or networking from the selector.
4. Rerun the focused test command and confirm GREEN.
5. Refactor only while tests stay green.
6. Commit:

       git add LoopFollow/Remote/APNsCredentialSelector.swift
       git commit -m "feat: select APNs credentials by environment"

## Task 3: Route both remote senders through the selector

**Modify:**

- LoopFollow/Remote/LoopAPNS/LoopAPNSService.swift
- LoopFollow/Remote/TRC/PushNotificationManager.swift

1. Replace LoopAPNSService.effectiveCredentials() with one selector call using:
   - LoopFollow Team ID and BuildDetails.default.isTestFlightBuild();
   - Remote Team ID and Storage.productionEnvironment;
   - the existing LoopFollow and Remote credential fields.
2. Replace PushNotificationManager's Team-ID-only initialization with the same selector.
3. Do not change APNs hosts, payloads, OTP behavior, return-notification details, or treatment behavior.
4. Rerun the focused tests and ensure both senders compile.
5. Commit:

       git add LoopFollow/Remote/LoopAPNS/LoopAPNSService.swift LoopFollow/Remote/TRC/PushNotificationManager.swift
       git commit -m "fix: route remote APNs through target credentials"

## Task 4: Expose separate credentials for mixed environments

**Modify:**

- LoopFollow/Remote/Settings/RemoteSettingsViewModel.swift
- LoopFollow/Remote/Settings/RemoteSettingsView.swift

1. Add requiresRemoteAPNsCredentials to the view model using the selector's Team ID/environment rule for Loop and Trio, and false for None.
2. Update loopAPNSSetup to validate Remote credentials when separate credentials are required.
3. Remove areTeamIdsDifferent only if no callers remain.
4. Show Remote APNs Key ID and Key fields in both remote settings sections when requiresRemoteAPNsCredentials is true.
5. Add a caption explaining that a separate key is needed for a different Team ID or APNs environment.
6. Never erase, copy, or reveal stored private keys.
7. Rerun focused tests, then compile a physical-device Debug build:

       xcodebuild -project LoopFollow.xcodeproj \
         -scheme LoopFollow \
         -configuration Debug \
         -destination 'id=5976EE99-FF62-5869-AB6A-13577A8A22F6' \
         -derivedDataPath /private/tmp/LoopFollowDerivedData \
         -clonedSourcePackagesDirPath /private/tmp/LoopFollowSourcePackages \
         build

8. Commit:

       git add LoopFollow/Remote/Settings/RemoteSettingsViewModel.swift LoopFollow/Remote/Settings/RemoteSettingsView.swift
       git commit -m "fix: require remote APNs key for mixed environments"

## Task 5: Run the complete verification gate

1. Run git status --short --branch and git diff --check.
2. Review the complete branch diff from the pre-change commit. Confirm it contains no real keys, device tokens, QR URLs, or secrets.
3. Run the full test suite:

       xcodebuild -project LoopFollow.xcodeproj \
         -scheme LoopFollow \
         -destination 'id=5976EE99-FF62-5869-AB6A-13577A8A22F6' \
         -derivedDataPath /private/tmp/LoopFollowDerivedData \
         -clonedSourcePackagesDirPath /private/tmp/LoopFollowSourcePackages \
         test

4. Classify package, signing, simulator, or device failures separately from code failures.
5. Rerun the Task 4 physical-device build and record its fresh result.

## Task 6: Install and perform non-treatment device verification

**Artifact:** /private/tmp/LoopFollowDerivedData/Build/Products/Debug-iphoneos/Loop Follow.app

1. Run xcrun devicectl list devices. Confirm device 5976EE99-FF62-5869-AB6A-13577A8A22F6 is available and unlocked.
2. Install without uninstalling or clearing app data:

       xcrun devicectl device install app \
         --device 5976EE99-FF62-5869-AB6A-13577A8A22F6 \
         '/private/tmp/LoopFollowDerivedData/Build/Products/Debug-iphoneos/Loop Follow.app'

3. Verify bundle ID com.WVNWL3N9G8.LoopFollow and launch the updated app.
4. Confirm the credential roles on device:
   - App APN settings: Production key for LoopFollow Live Activities.
   - Remote Loop settings: Sandbox key with target Production toggle off.
5. After the earlier APNs rate limit clears, restart only the LoopFollow Live Activity. Confirm sanitized logs show APNs success and activity binding. Do not repeatedly retry after a rate-limit response.
6. Confirm Remote Sandbox authentication using an invalid dummy device-token probe or existing non-treatment diagnostic. A valid key with a dummy token should return 400 BadDeviceToken; 403 indicates a credential/environment failure.
7. Do not send insulin, carbohydrate, override, meal, temporary-target, or other treatment payloads.
8. Report separately:
   - unit-test result;
   - physical-device build result;
   - install and launch result;
   - Live Activity APNs result;
   - Sandbox authentication probe result;
   - real treatment commands intentionally remain untested.
