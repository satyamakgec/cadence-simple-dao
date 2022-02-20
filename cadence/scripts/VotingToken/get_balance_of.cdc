import VotingToken from "../../contracts/VotingToken.cdc"


// Reads the balance of the given address
pub fun main(who: Address) {

    let publicCap = getAccount(who)
                        .getCapability(from: VotingToken.vaultPublicPath)
                        .check<&VotingToken.Vault{VotingToken.Balance}>() : "Capability doesn't exists"
    let publicCapRef = publicCap.borrow<&VotingToken.Vault{VotingToken.Balance}>() ??
                        panic("Could not borrow a reference to the given account")
    
    log("Current balance of the given address is : ")
    log(publicCapRef.balance)
}   