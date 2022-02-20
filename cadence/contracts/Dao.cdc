import VotingToken from "./VotingToken.cdc"

/// Dao contract allows to vote the token holders on a ballot and
/// conclude the proposal.
///
/// Simple contract to show how dao can be created using the cadence language.
/// It is not a production ready contract, It only depicts what any developer can do using the 
/// cadence language.
pub contract Dao {

    /// Minimum deposit needed to create a proposal.
    /// Token holders can create the ballot only if it provide the minimum deposit to
    /// the contract for escrow and it will get returned back once the ballot get concluded.
    pub let minimumDeposit: UFix64

    pub let ballotPath: StoragePath

    pub let ballotPublicPath: PublicPath

    event Voted(choiceId: UInt16, whom: Address)

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

        init(description: String, choices: [String;4]) {
            self.description = description
            self.choices = choices
            self.weights = {}
        }
    }

    pub resource interface BallotPublic {

        pub fun vote(choiceId: UInt16, voterImpression: @VotingToken.Vote)

        pub fun getProposalDetails() : (String, [String; 4])

        pub fun getListOfVoters(): [Address]

    }

    /// Ballot resource 
    /// It is a voting ballot which would allow to vote by the users.
    /// Anybody capability which has more the minimum deposit balance can create the ballot
    /// by providing the details of the proposal and at what checkpoint the voting power is going to used
    /// to conculde the result of the ballot.
    /// Then users can vote using there voting power.
    pub resource Ballot: BallotPublic {
        pub var proposalDetails: Proposal
        pub let checkpointId: UInt16
        pub let ballotWeightThreshold: UFix64
        /// Capability of the creator of the ballot get stored to return the funds that get escrowed/staked in the 
        /// contract during the creation of the ballot. Once ballot get conculded all the staked funds return backec
        /// to the given capability [TODO functionality]
        access(self) let creatorCapability: Capability<&AnyResource{VotingToken.Recevier}>

        /// Dictionary to keep track of the addresses that already voted on the ballot.
        access(self) var voters: {Address: Bool}

        access(self) let escrowedVault: @VotingToken.Vault

        init(
            description: String,
            choices: [String;4],
            checkpointId: UInt16,
            creatorCapability: Capability<&AnyResource{VotingToken.Recevier}>,
            escrowedVault: @VotingToken.Vault,
            ballotWeightThreshold: UFix64
        ) {
            pre {
                creatorCapability.check() : "Not a valid capability"
                description.length > 0 : "Description should not be empty"
            }
            self.checkpointId = checkpointId
            self.proposalDetails = Proposal(description: description, choices: choices)
            self.creatorCapability = creatorCapability
            self.voters = {}
            self.escrowedVault <- escrowedVault
            self.ballotWeightThreshold = ballotWeightThreshold
        }

        pub fun vote(choiceId: UInt16, voterImpression: @VotingToken.Vote) {
            pre {
                self.voters[voterPower.address] == nil : "Already voted"
                choiceId < 3: "Out of Index"
                voterImpression.owner == voterImpression.impression.address : "Resource owner and capability owner should be same"
                voterImpression.impression.check<&VotingToken.Vault{VotingToken.VotingPower}>() : "Unable to borrow the impression capability reference"
            }
            let voter = voterImpression.impression.borrow() ?? panic("Unable to borrow")
            let weight = voter.getVotingPower(at: self.checkpointId)
            assert(weight > 0.0, message: "Weight should be more than 0 to register vote")
            self.voters[voterPower.address] = true
            self.proposalDetails.weights[choiceId] = self.proposalDetails.weights[choiceId] ?? 0.0 + weight
            emit Voted(choiceId: choiceId, whom: voterImpression.owner)
            destroy voterImpression
        }

        pub fun getProposalDetails(): (String, [String; 4]) {
            return (self.proposalDetails.description, self.proposalDetails.choices)
        }

        pub fun getListOfVoters(): [Address] {
            return self.voters.keys
        }

        destroy() {
            destroy self.escrowedVault
        }
    }

    pub fun createBallot(
        description: String,
        choices: [String;4],
        checkpointId: UInt16,
        cap: Capability<&VotingToken.Vault{VotingToken.Balance, VotingToken.Recevier, VotingToken.VotingPower}>,
        escrowVault: @VotingToken.Vault
    ): @Ballot  {
        pre {
            cap.check() : "Not a valid capability"
            escrowVault.balance > Dao.minimumDeposit: "Should have minimum deposit"
        }
        let capRef = cap.borrow() ?? panic("unable to borrow")
        // Once ballot get created create a public capability of that resource so everyone is allowed to vote on that ballot.
        // Move funds to the contract it self as deposit which will get return back to the ballot creator once the ballot get concluded
        let ballot <- create Ballot(
            description: description,
            choices: choices,
            checkpointId: checkpointId,
            creatorCapability: cap as! Capability<&AnyResource{VotingToken.Recevier}>,
            escrowedVault: <- escrowVault,
            ballotWeightThreshold: UFix64(51) * VotingToken.totalSupply / 100.0
        )
        return <- ballot
    }


    /// Conculde the given ballot return the winning choice string or event could be emitted to keep
    /// track offchain and then destroy the ballot afterwards.
    pub fun conclude(ballot: @Ballot): String {
        var max = 0.0
        var winingChoice: UInt16 = 0
        var totalVoteWeight: UFix64 = 0.0
        for value in ballot.proposalDetails.weights.values {
            totalVoteWeight = totalVoteWeight + value
        }
        assert(totalVoteWeight >= ballotWeightThreshold, message: "Can't conclude right now")
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
        self.ballotPath = /storage/CadenceDaoTutorialBallot
        self.ballotPublicPath = /public/CadenceDaoTutorialBallot
    }
}