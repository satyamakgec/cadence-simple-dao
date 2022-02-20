import VotingToken from "../../contracts/VotingToken.cdc"


// Reads the voting power at the given checkpoint Id
pub fun main(checkpointId: UInt16?, who: Address) {

    let publicCap = getAccount(who)
                    .getCapability(from: VotingToken.vaultPublicPath)
                    .check<&VotingToken.Vault{VotingToken.VotingPower}>() : "Capability doesn't exists"
    let publicCapRef = publicCap.borrow<&VotingToken.Vault{VotingToken.VotingPower}>() ??
                        panic("Could not borrow a reference to the given account")
    
    let at = checkpointId ?? VotingToken.checkpointId
    
    log("CheckpointId at which voting power get queried:")
    log(at)
    log("Voting power at given checkpointId is: ")
    log(publicCapRef.getVotingPower(at: at))

}   