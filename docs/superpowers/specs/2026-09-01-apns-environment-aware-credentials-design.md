# APNs Environment-Aware Credentials Design

**Date:** 2026-09-01

## Problem

LoopFollow currently chooses credentials for remote commands by comparing only the LoopFollow and target-app Apple Developer Team IDs. When the Team IDs match, it reuses LoopFollow's APNs key.

That assumption fails when Apple issues environment-specific APNs keys and the two apps use different APNs environments. In the current setup:

- LoopFollow Live Activities use a Production device token and require the LoopFollow Production APNs key.
- The Xcode-installed Loop target uses a Sandbox device token and requires a Sandbox APNs key.
- Both apps use the same Developer Team ID.

Reusing the Production key for Sandbox remote commands produces `BadEnvironmentKeyInToken`; replacing the LoopFollow key with the Sandbox key breaks Live Activities.

## Goals

- Select remote-command APNs credentials using both Developer Team ID and APNs environment.
- Preserve existing same-team, same-environment behavior.
- Keep Live Activity credential selection unchanged.
- Make separate Remote APNs fields visible and required when either the team or environment differs.
- Apply one credential-selection rule to both Loop APNS and Trio Remote Control senders.
- Verify the change without sending insulin, carbohydrates, overrides, or other treatment commands.

## Non-Goals

- Change Loop, Nocturne, Nightscout, or their data formats.
- Change how LoopFollow determines its own APNs environment.
- Automatically copy or migrate private keys between settings.
- Exercise a real remote treatment command during automated or device verification.

## Design

### Environment-aware credential selector

Add a small pure selector that receives:

- LoopFollow Team ID and APNs environment.
- Remote target Team ID and APNs environment.
- LoopFollow APNs credentials.
- Remote APNs credentials.

The selector reuses LoopFollow credentials only when both Team ID and environment match. If either differs, it selects the Remote credentials and the remote target's Team ID.

An empty remote Team ID retains the current fallback to the LoopFollow Team ID, but environment mismatch still requires Remote credentials. This preserves the existing same-environment setup while preventing an environment-specific key from being used against the wrong APNs endpoint.

### Integration points

- `LoopAPNSService` uses the selector for setup validation and command sending.
- `PushNotificationManager` uses the same selector for Trio command sending.
- `RemoteSettingsViewModel` exposes whether separate Remote credentials are required using the same team/environment rule.
- `RemoteSettingsView` displays Remote APNs Key ID and Key fields when separate credentials are required.
- Live Activity and return-notification code continue using LoopFollow's own credentials and build environment.

### User experience

For a Production LoopFollow build controlling a Sandbox Loop build:

- App APN settings retain the Production key for LoopFollow Live Activities.
- Remote settings show separate APNs fields.
- The Remote fields contain the Sandbox key.
- The Remote Production toggle remains off.

No existing key values are deleted or silently copied. Existing same-team, same-environment configurations continue to reuse the LoopFollow credentials and do not show redundant Remote fields.

### Error handling and privacy

- Existing validation errors remain in place for missing or malformed credentials.
- Validation checks the credentials selected for the actual target environment.
- Logs must not include private-key material or complete device tokens.
- No diagnostic path introduced by this change sends a treatment command.

## Test Strategy

Add unit tests for the pure selector covering:

1. Same team and same environment selects LoopFollow credentials.
2. Same team and different environment selects Remote credentials.
3. Different team and same environment selects Remote credentials.
4. Different team and different environment selects Remote credentials.
5. Empty remote Team ID falls back to the LoopFollow Team ID while still respecting environment mismatch.
6. The separate-credential requirement matches the selection rule.

Run the LoopFollow unit-test target, build the app for the explicitly identified physical iPhone, install it without clearing app data, and verify the installed bundle/process.

Device verification is limited to:

- Confirming the Remote credential fields appear for the mixed-environment configuration.
- Restarting the LoopFollow Live Activity after APNs rate limiting has cleared.
- Confirming Live Activity APNs success through sanitized logs.
- Confirming remote Sandbox authentication using a non-treatment diagnostic or invalid dummy device-token probe.

Successful build, installation, and APNs authentication are reported separately from any untested real treatment-command behavior.

## Compatibility and Risk

This is a LoopFollow-only change. It does not alter Nocturne or Loop APIs and introduces no database or payload migration.

The primary compatibility risk is showing separate Remote credential fields for configurations that previously relied on same-team reuse despite an environment mismatch. That is intentional: environment-specific keys cannot be safely reused across APNs endpoints. Same-team, same-environment users retain the existing behavior.
