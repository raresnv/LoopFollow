// LoopFollow
// APNsCredentialSelector.swift

import Foundation

struct APNsCredentials: Equatable {
    let apnsKey: String
    let keyId: String
    let teamId: String
}

enum APNsCredentialSelector {
    static func requiresRemoteCredentials(
        loopFollowTeamId: String,
        loopFollowProductionEnvironment: Bool,
        remoteTeamId: String,
        remoteProductionEnvironment: Bool
    ) -> Bool {
        let targetTeamId = remoteTeamId.isEmpty ? loopFollowTeamId : remoteTeamId

        return targetTeamId != loopFollowTeamId ||
            remoteProductionEnvironment != loopFollowProductionEnvironment
    }

    static func select(
        loopFollowCredentials: APNsCredentials,
        loopFollowProductionEnvironment: Bool,
        remoteCredentials: APNsCredentials,
        remoteProductionEnvironment: Bool
    ) -> APNsCredentials {
        let targetTeamId = remoteCredentials.teamId.isEmpty
            ? loopFollowCredentials.teamId
            : remoteCredentials.teamId

        guard requiresRemoteCredentials(
            loopFollowTeamId: loopFollowCredentials.teamId,
            loopFollowProductionEnvironment: loopFollowProductionEnvironment,
            remoteTeamId: targetTeamId,
            remoteProductionEnvironment: remoteProductionEnvironment
        ) else {
            return loopFollowCredentials
        }

        return APNsCredentials(
            apnsKey: remoteCredentials.apnsKey,
            keyId: remoteCredentials.keyId,
            teamId: targetTeamId
        )
    }
}
