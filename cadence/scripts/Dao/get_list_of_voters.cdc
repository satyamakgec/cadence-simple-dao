import Dao from "../../contracts/Dao.cdc"

pub fun main(ballotOwner: Address) {

    let ballotOwnerCap = getAccount(ballotOwner)
                        .getCapability<&Dao.Ballot{Dao.BallotPublic}>()
                        .check() : "Ballot resoruce doesn't exists"
    
    let ballotOwnerCapRef = ballotOwnerCap.borrow()!

    let votersList = ballotOwnerCapRef.getListOfVoters()

    log("Voters fetched successfully")
    log("No. of voters are: ")
    log(votersList.length)

    return votersList

}