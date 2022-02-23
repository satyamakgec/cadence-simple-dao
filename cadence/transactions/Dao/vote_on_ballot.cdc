import Dao from "../../contracts/Dao.cdc"
import VotingToken from "../../contracts/VotingToken.cdc"

transaction(ownerOfBallot: Address, preferenceChoice: UInt16) {

    var ballotCapRef: &Dao.Ballot{Dao.BallotPublic}

    var voterPublicCap: Capability<&VotingToken.Vault{VotingToken.Balance, VotingToken.Recevier, VotingToken.VotingPower}>

    var voteResource: @VotingToken.Vote

    prepare(signer: AuthAccount) {

        assert(preferenceChoice <= 3, message: "Invalid preference choice")
        
        self.voterPublicCap = signer
                                .getCapability<&VotingToken.Vault{VotingToken.Balance, VotingToken.Recevier, VotingToken.VotingPower}>(VotingToken.vaultPublicPath)
        
        if !self.voterPublicCap.check() {
            panic("Voter public capability doesn't exists")
        }

        let ballotCap = getAccount(ownerOfBallot)
                        .getCapability<&Dao.Ballot{Dao.BallotPublic}>(Dao.ballotPublicPath) 

        if !ballotCap.check() {
            panic("Unable to borrow ballot resource reference")
        }

        self.ballotCapRef = ballotCap.borrow()!
        
        // Store the temporary vote impression to assign the owner of that resource.
        let temporaryVoteImpressionResource <- VotingToken.createVoteImpression(impression: self.voterPublicCap as! Capability<&VotingToken.Vault{VotingToken.VotingPower}>)
        signer.save<@VotingToken.Vote>(<- temporaryVoteImpressionResource, to: /storage/CadenceVotingTokenTutorialImpression)
        
        // Load the same resource so it can be use to vote on a created ballot
        self.voteResource <- signer.load<@VotingToken.Vote>(from: /storage/CadenceVotingTokenTutorialImpression) ??
                            panic("Unable to load the vote resource")
    }

    execute {
        // Vote by the signer
        self.ballotCapRef.vote(choiceId: preferenceChoice, voterImpression: <- self.voteResource)
    }

}