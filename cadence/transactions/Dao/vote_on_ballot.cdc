import Dao from "../../contracts/Dao.cdc"
import VotingToken from "../../contracts/VotingToken.cdc"

transaction(ownerOfBallot: Address, preferenceChoice: UInt16) {

    var ballotCapRef: Capability<&Dao.Ballot{Dao.BallotPublic}>

    var voterPublicCapRef: Capability<&VotingToken.Vault{VotingToken.Balance, VotingToken.Recevier, VotingToken.VotingPower}>

    var voteResource: @VotingToken.Vote

    pre {
        preferenceChoice <= 3 : "Invalid preference choice"
    }

    prepare(signer: AuthAccount) {
        
        self.voterPublicCapRef = signer
                                    .borrow<&VotingToken.Vault{VotingToken.Balance, VotingToken.Recevier, VotingToken.VotingPower}>(from: VotingToken.vaultPublicPath) ??
                                    panic("Unable to borrow the ballot creator public reference")

        let ballotCap = getAccount(ownerOfBallot)
                        .getCapability<&Dao.Ballot{Dao.BallotPublic}>(Dao.ballotPublicPath)
                        .check(): "Unable to borrow ballot resource reference"
        
        self.ballotCapRef = ballotCap.borrow()!
        
        // Store the temporary vote impression to assign the owner of that resource.
        let temporaryVoteImpressionResource <- VotingToken.createVoteImpression(impression: self.voterPublicCapRef as! Capability<&VotingToken.Vault{VotingToken.VotingPower}>)
        signer.save<@VotingToken.Vote>(<- temporaryVoteImpressionResource, target: /storage/CadenceVotingTokenTutorialImpression)
        
        // Load the same resource so it can be use to vote on a created ballot
        self.voteResource <- signer.load<@VotingToken.Vote>(from: /storage/CadenceVotingTokenTutorialImpression) ??
                            panic("Unable to load the vote resource")
    }

    execute {
        // Vote by the signer
        self.ballotCapRef.vote(choiceId: preferenceChoice, voterImpression: <- self.voteResource)
    }

}