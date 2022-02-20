import Dao from "../../contracts/Dao.cdc"

pub fun main(ballotOwner: Address) {

    let ballotOwnerCap = getAccount(ballotOwner)
                        .getCapability<&Dao.Ballot{Dao.BallotPublic}>()
                        .check() : "Ballot resoruce doesn't exists"
    
    let ballotOwnerCapRef = ballotOwnerCap.borrow()!

    let proposalDetails = ballotOwnerCapRef.getProposalDetails()

    log("Proposal description")
    log(proposalDetails[0])
    log("Proposal Choices -> ")
    for choice in proposalDetails[1] {
        log(choice)
    }

    return proposalDetails

}