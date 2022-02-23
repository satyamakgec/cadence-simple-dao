import VotingToken from "../../contracts/VotingToken.cdc"

/// Used to create the checkpoint by the adminstrator
transaction {

    // Store the private capability ref of the adminstrator resource
    var administratorRef : &VotingToken.Administrator

    let currentCheckpointId : UInt16 

    prepare(signer: AuthAccount) {

        self.administratorRef = signer.borrow<&VotingToken.Administrator>(from: VotingToken.administratorResourcePath) ??
                                panic("Unable to borrow the administrator resource")
        self.currentCheckpointId = VotingToken.checkpointId

        log("Checkpoint Id before the checkpoint creation")
        log(self.currentCheckpointId)
        
    }

    execute {
        // Create checkpoint
        self.administratorRef.createCheckpoint()

        log("Checkpoint successfully created")
        log("Checkpoint Id after the checkpoint creation")
        log(VotingToken.checkpointId)
    }

    post {
        (self.currentCheckpointId + 1) == VotingToken.checkpointId : "Incorrect checkpoint update happen"
    }
}