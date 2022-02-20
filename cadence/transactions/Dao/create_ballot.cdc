import Dao from "../../contracts/Dao.cdc"
import VotingToken from "../../contracts/VotingToken.cdc"

transaction(description: String, choices: [String;4], checkpointId: UInt16, preferenceChoice: UInt16) {

    var ballotCapRef: Capability<&Dao.Ballot{Dao.BallotPublic}>

    var creatorPublicCapRef: Capability<&VotingToken.Vault{VotingToken.Balance, VotingToken.Recevier, VotingToken.VotingPower}>

    var voteResource: @VotingToken.Vote

    pre {
        checkpointId <= VotingToken.checkpointId : "CheckpointId should existed in the VotingToken"
        description.length >= UInt16(0) : "Zero length description is not allowed"
        preferenceChoice <= 3 : "Invalid preference choice"
    }

    prepare(signer: AuthAccount) {
        
        let ballotCreator = signer
                            .borrow<&VotingToken.Vault>(from: VotingToken.vaultPath)
                            panic("Unable to borrow the ballot creator reference")
        
        self.creatorPublicCapRef = signer
                                    .borrow<&VotingToken.Vault{VotingToken.Balance, VotingToken.Recevier, VotingToken.VotingPower}>(from: VotingToken.vaultPublicPath) ??
                                    panic("Unable to borrow the ballot creator public reference")

        // Get the vault that will get used as the escrowed in the contract.
        let temporaryVault <- ballotCreator.withdraw(amount: Dao.minimumDeposit)

        // Create the ballot
        let temporaryBallot <- Dao.createBallot(
            description: description,
            choices: choices,
            checkpointId: checkpointId,
            cap: creatorPublicCapRef,
            escrowVault: <-temporaryVault
        )

        signer.save<&Dao.Ballot>(<-temporaryBallot, target: Dao.ballotPath)

        // Create public capability
        signer.link<@Dao.Ballot{Dao.BallotPublic}>(Dao.ballotPublicPath, target: Dao.ballotPath)

        self.ballotCapRef = signer.borrow<&Dao.Ballot{Dao.BallotPublic}>(Dao.ballotPublicPath)??
                            panic("Unable to borrow ballot resource reference")
        
        // Store the temporary vote impression to assign the owner of that resource.
        let temporaryVoteImpressionResource <- VotingToken.createVoteImpression(impression: self.creatorPublicCapRef as! Capability<&VotingToken.Vault{VotingToken.VotingPower}>)
        signer.save<@VotingToken.Vote>(<- temporaryVoteImpressionResource, target: /storage/CadenceVotingTokenTutorialImpression)
        
        // Load the same resource so it can be use to vote on a created ballot
        self.voteResource <- signer.load<@VotingToken.Vote>(from: /storage/CadenceVotingTokenTutorialImpression) ??
                            panic("Unable to load the vote resource")
    }

    execute {
        // Vote by the ballot creator
        self.ballotCapRef.vote(choiceId: preferenceChoice, voterImpression: <- self.voteResource)
    }

}