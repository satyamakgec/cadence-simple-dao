import VotingToken from "../../contracts/VotingToken.cdc"

transaction {

    // Store the private capability ref of the adminstrator resource
    var administratorRef : Capability<&VotingToken.Administrator>

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
    }

    post {
        assert(self.currentCheckpointId + UInt16(1) == VotingToken.checkpointId, message: "Incorrect checkpoint update happen")

        log("Checkpoint Id after the checkpoint creation")
        log(VotingToken.checkpointId)
    }
}