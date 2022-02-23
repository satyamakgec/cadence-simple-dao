import VotingToken from "../../contracts/VotingToken.cdc"


// Reads the voting power at the given checkpoint Id
pub fun main(checkpointId: UInt16?, who: Address): UFix64 {

    let publicCapRef = getAccount(who)
                    .getCapability(VotingToken.vaultPublicPath)
                    .borrow<&VotingToken.Vault{VotingToken.VotingPower}>() ??
                        panic("Could not borrow a reference to the given account")
    
    let at = checkpointId ?? VotingToken.checkpointId
    let votingPowerAt = publicCapRef.getVotingPower(at: at)
    log("CheckpointId at which voting power get queried:")
    log(at)
    log("Voting power at given checkpointId is: ")
    log(votingPowerAt)
    return votingPowerAt
}   