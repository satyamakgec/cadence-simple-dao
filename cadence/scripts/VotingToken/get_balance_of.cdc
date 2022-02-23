import VotingToken from "../../contracts/VotingToken.cdc"

// Reads the balance of the given address
pub fun main(who: Address): UFix64 {

    let publicCapRef = getAccount(who)
                        .getCapability(VotingToken.vaultPublicPath)
                        .borrow<&VotingToken.Vault{VotingToken.Balance}>() ??
                        panic("Could not borrow a reference to the given account")
    
    log("Current balance of the given address is : ")
    log(publicCapRef.balance)
    return publicCapRef.balance
}   