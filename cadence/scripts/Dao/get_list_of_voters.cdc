import Dao from "../../contracts/Dao.cdc"

pub fun main(ballotOwner: Address): [Address] {

    let ballotOwnerCapRef = getAccount(ballotOwner)
                        .getCapability(Dao.ballotPublicPath)
                        .borrow<&Dao.Ballot{Dao.BallotPublic}>() ?? panic("Unable to borrow the ballot public resource")
    
    let votersList = ballotOwnerCapRef.getListOfVoters()

    log("Voters fetched successfully")
    log("No. of voters are: ")
    log(votersList.length)

    return votersList

}