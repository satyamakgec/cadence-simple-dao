import Dao from "../../contracts/Dao.cdc"
import VotingToken from "../../contracts/VotingToken.cdc"

/// Conculde transaction where the ballot creator calls `conclude` to calculate the results of the voting.
transaction() {

    let ballot : @Dao.Ballot

    prepare(signer: AuthAccount) {
        // Load ballot resource which need to conclude
        self.ballot <- signer.load<@Dao.Ballot>(from: Dao.ballotPath) ??
                      panic("Ballot resource doesn't exists")
    }

    execute {
        let winningString = Dao.conclude(ballot: <- self.ballot)
        log("Winning choice of the proposal : ")
        log(winningString)
    }
}