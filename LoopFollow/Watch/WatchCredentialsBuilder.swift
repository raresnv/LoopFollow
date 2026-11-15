// LoopFollow
// WatchCredentialsBuilder.swift

import Foundation

/// Collects what the watch needs to fetch data and send commands on its own.
enum WatchCredentialsBuilder {
    static func build() -> WatchCredentials {
        WatchCredentials(
            nightscoutURL: Storage.shared.url.value,
            nightscoutToken: Storage.shared.token.value,
            dexcomUsername: Storage.shared.shareUserName.value,
            dexcomPassword: Storage.shared.sharePassword.value,
            dexcomServer: Storage.shared.shareServer.value,
            remote: remote()
        )
    }

    private static func remote() -> WatchCredentials.Remote? {
        guard Storage.shared.watchRemoteCommands.value, let kind = WatchStateBuilder.remoteKind() else { return nil }
        let signing = APNsCredentialSelector.select(
            loopFollowCredentials: APNsCredentials(
                apnsKey: Storage.shared.lfApnsKey.value,
                keyId: Storage.shared.lfKeyId.value,
                teamId: BuildDetails.default.teamID ?? ""
            ),
            loopFollowProductionEnvironment: BuildDetails.default.isTestFlightBuild(),
            remoteCredentials: APNsCredentials(
                apnsKey: Storage.shared.remoteApnsKey.value,
                keyId: Storage.shared.remoteKeyId.value,
                teamId: Storage.shared.teamId.value ?? ""
            ),
            remoteProductionEnvironment: Storage.shared.productionEnvironment.value
        )
        return WatchCredentials.Remote(
            kind: kind,
            deviceToken: Storage.shared.deviceToken.value,
            bundleID: Storage.shared.bundleId.value,
            production: Storage.shared.productionEnvironment.value,
            apnsKey: signing.apnsKey,
            keyID: signing.keyId,
            teamID: signing.teamId,
            user: Storage.shared.user.value,
            sharedSecret: Storage.shared.sharedSecret.value,
            loopQRCodeURL: Storage.shared.loopAPNSQrCodeURL.value,
            returnNotification: ReturnNotificationInfo.loopFollow()
        )
    }
}
