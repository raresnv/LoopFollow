// LoopFollow
// APNsCredentialSelectorTests.swift

@testable import LoopFollow
import Testing

struct APNsCredentialSelectorTests {
    private let loopFollowCredentials = APNsCredentials(
        apnsKey: "LF_KEY",
        keyId: "LF_KEY_ID",
        teamId: "TEAM_A"
    )

    private let remoteCredentials = APNsCredentials(
        apnsKey: "REMOTE_KEY",
        keyId: "REMOTE_KEY_ID",
        teamId: "TEAM_A"
    )

    @Test("same team and environment reuse LoopFollow credentials")
    func sameTeamAndEnvironmentReuseLoopFollowCredentials() {
        let selected = APNsCredentialSelector.select(
            loopFollowCredentials: loopFollowCredentials,
            loopFollowProductionEnvironment: true,
            remoteCredentials: remoteCredentials,
            remoteProductionEnvironment: true
        )

        #expect(selected == loopFollowCredentials)
        #expect(APNsCredentialSelector.requiresRemoteCredentials(
            loopFollowTeamId: "TEAM_A",
            loopFollowProductionEnvironment: true,
            remoteTeamId: "TEAM_A",
            remoteProductionEnvironment: true
        ) == false)
    }

    @Test("same team and different environment use Remote credentials")
    func sameTeamAndDifferentEnvironmentUseRemoteCredentials() {
        let selected = APNsCredentialSelector.select(
            loopFollowCredentials: loopFollowCredentials,
            loopFollowProductionEnvironment: true,
            remoteCredentials: remoteCredentials,
            remoteProductionEnvironment: false
        )

        #expect(selected == remoteCredentials)
        #expect(APNsCredentialSelector.requiresRemoteCredentials(
            loopFollowTeamId: "TEAM_A",
            loopFollowProductionEnvironment: true,
            remoteTeamId: "TEAM_A",
            remoteProductionEnvironment: false
        ))
    }

    @Test("different team uses Remote credentials in the same environment")
    func differentTeamUsesRemoteCredentialsInSameEnvironment() {
        let remote = APNsCredentials(
            apnsKey: "REMOTE_KEY",
            keyId: "REMOTE_KEY_ID",
            teamId: "TEAM_B"
        )

        let selected = APNsCredentialSelector.select(
            loopFollowCredentials: loopFollowCredentials,
            loopFollowProductionEnvironment: true,
            remoteCredentials: remote,
            remoteProductionEnvironment: true
        )

        #expect(selected == remote)
    }

    @Test("different team and environment use Remote credentials")
    func differentTeamAndEnvironmentUseRemoteCredentials() {
        let remote = APNsCredentials(
            apnsKey: "REMOTE_KEY",
            keyId: "REMOTE_KEY_ID",
            teamId: "TEAM_B"
        )

        let selected = APNsCredentialSelector.select(
            loopFollowCredentials: loopFollowCredentials,
            loopFollowProductionEnvironment: true,
            remoteCredentials: remote,
            remoteProductionEnvironment: false
        )

        #expect(selected == remote)
        #expect(APNsCredentialSelector.requiresRemoteCredentials(
            loopFollowTeamId: "TEAM_A",
            loopFollowProductionEnvironment: true,
            remoteTeamId: "TEAM_B",
            remoteProductionEnvironment: false
        ))
    }

    @Test("empty Remote Team ID falls back to LoopFollow Team ID")
    func emptyRemoteTeamIdFallsBackToLoopFollowTeamId() {
        let remoteWithoutTeam = APNsCredentials(
            apnsKey: "REMOTE_KEY",
            keyId: "REMOTE_KEY_ID",
            teamId: ""
        )

        let selected = APNsCredentialSelector.select(
            loopFollowCredentials: loopFollowCredentials,
            loopFollowProductionEnvironment: true,
            remoteCredentials: remoteWithoutTeam,
            remoteProductionEnvironment: false
        )

        #expect(selected.apnsKey == "REMOTE_KEY")
        #expect(selected.keyId == "REMOTE_KEY_ID")
        #expect(selected.teamId == "TEAM_A")
    }

    @Test("environment mismatch requires Remote credentials with an empty Team ID")
    func environmentMismatchRequiresRemoteCredentialsWithEmptyTeamId() {
        #expect(APNsCredentialSelector.requiresRemoteCredentials(
            loopFollowTeamId: "TEAM_A",
            loopFollowProductionEnvironment: true,
            remoteTeamId: "",
            remoteProductionEnvironment: false
        ))
    }
}
