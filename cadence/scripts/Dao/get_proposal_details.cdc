import Dao from "../../contracts/Dao.cdc"

pub fun main(ballotOwner: Address): Dao.ProposalDetails {

    let ballotOwnerCapRef = getAccount(ballotOwner)
                        .getCapability(Dao.ballotPublicPath)
                        .borrow<&Dao.Ballot{Dao.BallotPublic}>() ?? panic("Unable to borrow the ballot public resource")
    
    let proposalDetails = ballotOwnerCapRef.getProposalDetails()

    log("Proposal description")
    log(proposalDetails.description)
    log("Proposal Choices -> ")
    for choice in proposalDetails.choices {
        log(choice)
    }

    return proposalDetails
}