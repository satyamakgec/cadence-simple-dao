import Dao from "../../contracts/Dao.cdc"
import VotingToken from "../../contracts/VotingToken.cdc"

transaction(description: String, choices: [String;4], checkpointId: UInt16, preferenceChoice: UInt16) {

    var ballotCapRef: &Dao.Ballot{Dao.BallotPublic}

    var creatorPublicCap: Capability<&VotingToken.Vault{VotingToken.Balance, VotingToken.Recevier, VotingToken.VotingPower}>

    var voteResource: @VotingToken.Vote

    prepare(signer: AuthAccount) {

        assert(checkpointId <= VotingToken.checkpointId, message : "CheckpointId should existed in the VotingToken")
        assert(description.length >= 0, message : "Zero length description is not allowed")
        assert(preferenceChoice <= 3, message: "Invalid preference choice")
        
        let ballotCreator = signer
                            .borrow<&VotingToken.Vault>(from: VotingToken.vaultPath) ??
                            panic("Unable to borrow the ballot creator reference")
        
        self.creatorPublicCap = signer.getCapability<&VotingToken.Vault{VotingToken.Balance, VotingToken.Recevier, VotingToken.VotingPower}>(VotingToken.vaultPublicPath)

        if !self.creatorPublicCap.check() {
            panic("Creator capability doesn't exists")
        }

        // Get the vault that will get used as the escrowed in the contract.
        let temporaryVault <- ballotCreator.withdraw(amount: Dao.minimumDeposit)

        // Create the ballot
        let temporaryBallot <- Dao.createBallot(
            description: description,
            choices: choices,
            checkpointId: checkpointId,
            cap: self.creatorPublicCap,
            escrowVault: <-temporaryVault
        )

        signer.save<@Dao.Ballot>(<-temporaryBallot, to: Dao.ballotPath)

        // Create public capability
        signer.link<&Dao.Ballot{Dao.BallotPublic}>(Dao.ballotPublicPath, target: Dao.ballotPath)

        self.ballotCapRef = signer.getCapability<&Dao.Ballot{Dao.BallotPublic}>(Dao.ballotPublicPath)
                            .borrow() ??
                            panic("Unable to borrow ballot resource reference")
        
        // Store the temporary vote impression to assign the owner of that resource.
        let temporaryVoteImpressionResource <- VotingToken.createVoteImpression(impression: self.creatorPublicCap as! Capability<&VotingToken.Vault{VotingToken.VotingPower}>)
        signer.save<@VotingToken.Vote>(<- temporaryVoteImpressionResource, to: /storage/CadenceVotingTokenTutorialImpression)
        
        // Load the same resource so it can be use to vote on a created ballot
        self.voteResource <- signer.load<@VotingToken.Vote>(from: /storage/CadenceVotingTokenTutorialImpression) ??
                            panic("Unable to load the vote resource")
    }

    execute {
        // Vote by the ballot creator
        self.ballotCapRef.vote(choiceId: preferenceChoice, voterImpression: <- self.voteResource)
    }

}