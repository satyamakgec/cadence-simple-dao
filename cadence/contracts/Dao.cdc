import VotingToken from "./VotingToken.cdc"

pub contract Dao {

    /// Minimum deposit needed to create a proposal.
    pub let minimumDeposit: UFix64

    /// It is a data structure of proposal where the description and related choices stored.
    /// It also stored the weights assigned to the choices.
    /// Note - Only allowing to have 4 choices
    /// Ex - Choice 1 -> x weight
    ///    - Choice 2 -> y weight
    ///    - Choice 3 -> z weight
    ///    - Choice 4 -> a weight
    /// If a>x>y>z then a is the choice that is winner for the given proposal.
    pub struct Proposal {
        pub let description: String
        pub let choices: [String; 4]
        access(contract) var weights: {UInt16: UFix64}

        init(desc: String, choices: [String;4]) {
            self.description = desc
            self.choices = choices
            self.weights = {}
        }
    }


    /// Ballot resource 
    /// It is a voting ballot which would allow to vote by the users.
    /// Anybody capability which has more the minimum deposit balance can create the ballot
    /// by providing the details of the proposal and at what checkpoint the voting power is going to used
    /// to conculde the result of the ballot.
    /// Then users can vote using there voting power.
    pub resource Ballot {
        pub var proposalDetails: Proposal
        pub let checkpointId: UInt16
        /// Capability of the creator of the ballot get stored to return the funds that get escrowed/staked in the 
        /// contract during the creation of the ballot. Once ballot get conculded all the staked funds return backec
        /// to the given capability [TODO functionality]
        pub let creatorCapability: Capability<&AnyResource{VotingToken.Recevier}>

        /// Dictionary to keep track of the addresses that already voted on the ballot.
        access(self) var voters: {Address: Bool}

        init(desc: String, choices: [String;4], checkpointId: UInt16, creatorCapability: Capability<&AnyResource{VotingToken.Recevier}>) {
            self.checkpointId = checkpointId
            self.proposalDetails = Proposal(desc: desc, choices: choices)
            self.creatorCapability = creatorCapability
            self.voters = {}
        }

        pub fun vote(choiceId: UInt16, voterPower: Capability<&VotingToken.Vault{VotingToken.VotingPower}>) {
            pre {
                self.voters[voterPower.address] == nil : "Already voted"
                choiceId < 3: "Out of Index"
            }
            let voter = voterPower.borrow() ?? panic("Unable to borrow")
            let weight = voter.getVotingPower(at: self.checkpointId)
            assert(weight > 0.0, message: "Weight should be more than 0 to register vote")
            self.voters[voterPower.address] = true
            self.proposalDetails.weights[choiceId] = self.proposalDetails.weights[choiceId] ?? 0.0 + weight
        }
    }

    pub fun createBallot(
        desc: String,
        choices: [String;4],
        checkpointId: UInt16,
        cap: Capability<&VotingToken.Vault{VotingToken.Balance, VotingToken.Provider, VotingToken.Recevier, VotingToken.VotingPower}>
        preferenceChoice: UInt16
    ): @Ballot  {
        let capRef = cap.borrow() ?? panic("unable to borrow")
        assert(capRef.balance >= Dao.minimumDeposit, message: "Balance should be greater than minimum despoit")
        // Once ballot get created create a public capability of that resource so everyone is allowed to vote on that ballot.
        let ballot <- create Ballot(desc: desc, choices: choices, checkpointId: checkpointId, creatorCapability: cap as! Capability<&AnyResource{VotingToken.Recevier}>)
        ballot.vote(choiceId: preferenceChoice, voterPower: cap as! Capability<&VotingToken.Vault{VotingToken.VotingPower}>)
        //TODO: Move funds to the contract it self as deposit which will get return back to the ballot creator once the ballot get concluded
        return <- ballot
    }


    /// Conculde the given ballot return the winning choice string or event could be emitted to keep
    /// track offchain and then destroy the ballot afterwards.
    pub fun conclude(ballot: @Ballot): String {
        var max = 0.0
        var winingChoice: UInt16 = 0
        for index in ballot.proposalDetails.weights.keys {
            var concludedWeight = ballot.proposalDetails.weights[index] ?? 0.0
            if concludedWeight > max {
                max = concludedWeight
                winingChoice = index
            }
        }
        let winningChoiceString = ballot.proposalDetails.choices[winingChoice]
        destroy ballot
        return winningChoiceString
    }

    init() {
        self.minimumDeposit = 100.0
    }
}