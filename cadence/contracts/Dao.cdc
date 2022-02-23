import VotingToken from "./VotingToken.cdc"

/// Dao contract allows to vote the token holders on a ballot and
/// conclude the proposal.
///
/// Simple contract to show how dao can be created using the cadence language.
/// Note - It is not a production ready contract, It only depicts what any developer can do using the 
/// cadence language.
pub contract Dao {

    /// Minimum deposit needed to create a proposal.
    /// Token holders can create the ballot only if holder would provide the minimum deposit to
    /// the contract for escrow and it will get returned back once the ballot get concluded.
    pub let minimumDeposit: UFix64

    /// It is a good practice to store the paths in a contract variable instead of
    /// hanging strings in the contract, It helps avoid the human mistake of re-writing the storage paths
    /// again and again.
    ///
    /// Storage path where ballot resource get stored.
    pub let ballotPath: StoragePath

    /// Public path where Capability for BallotPublic resource get linked
    pub let ballotPublicPath: PublicPath

    /// Emitted when the token holder voted for a given ballot
    /// It is helpful for the offchain data aggregation to know what
    /// choice get preferred by `whom` i.e token holder.
    pub event Voted(choiceId: UInt16, whom: Address)

    /// It is a data structure of proposal where the description and related choices stored.
    /// It also stored the weights assigned to the choices.
    /// Note - Only allowing to have 4 choices
    /// Ex - Choice 1 -> x weight
    ///    - Choice 2 -> y weight
    ///    - Choice 3 -> z weight
    ///    - Choice 4 -> a weight
    /// If a>x>y>z then a is the choice that is winner for the given proposal.
    pub struct Proposal {
        // Variable contains the details of the proposal i.e description & choices. 
        pub let details: ProposalDetails

        // Dictionary to keep track of vote power assigned to choice.
        access(contract) var weights: {UInt16: UFix64}

        init(description: String, choices: [String;4]) {
            self.details = ProposalDetails(description: description, choices: choices)
            self.weights = {}
        }
    }

    /// It can be extended more to add adittional details about the proposal.
    /// As it is a non-production ready code we are only storing very generic information. 
    pub struct ProposalDetails {
        // Simple decription about the proposal, ex - if we create a ballot for
        // "Should George . R . Martin create a new GOT season" then that string would
        // become the description of the proposal. 
        pub let description: String

        // Choices that token holder can choose to vote on
        // Ex -
        // Ballot description - "Should George . R . Martin create a new GOT season"
        // Choice 1 - Yes
        // Choice 2 - No
        // Choice 3 - I don't care
        // Choice 4 - He should had not create the GOT at first place.
        pub let choices: [String; 4]

        init(description: String, choices: [String ; 4]) {
            self.description = description
            self.choices = choices
        }
    }

    /// Resource interface that shared publically.
    /// Ballot owner can make a public capability for this resource interface
    /// that will allow the token holder to vote on it using the `vote` function.
    pub resource interface BallotPublic {

        // Allowed to vote on a ballot by providing the `choiceId` & `voterImpression`
        // i.e resource that contains the capability which would allow to read voting power of the
        // resource owner.
        pub fun vote(choiceId: UInt16, voterImpression: @VotingToken.Vote)

        // Fetch the details of the proposal
        pub fun getProposalDetails() : ProposalDetails

        // Fetch the list of voters that already voted on the given ballot
        pub fun getListOfVoters(): [Address]

    }

    /// Ballot resource 
    /// It is a voting ballot which would allow to vote by the users.
    /// Anybody capability which has more the minimum deposit balance can create the ballot
    /// by providing the details of the proposal and at what checkpoint the voting power is going to used
    /// to conculde the result of the ballot.
    /// Then users can vote using there voting power.
    pub resource Ballot: BallotPublic {

        // Proposal object to keep the details of the proposal and the vote allocation as well.
        access(contract) var proposal: Proposal

        // Checkpoint Id at which voting power get used of a voter.
        pub let checkpointId: UInt16

        // Threshold value at which ballot can be concluded
        // As per the current implementation it is 51 % supply of the total supply of voting token.
        pub let ballotWeightThreshold: UFix64

        // Capability of the creator of the ballot get stored to return the funds that get escrowed/staked in the 
        // contract during the creation of the ballot. Once ballot get conculded all the staked funds return back
        // to the given capability
        access(self) let creatorCapability: Capability<&AnyResource{VotingToken.Recevier}>

        // Dictionary to keep track of the addresses that already voted on the ballot.
        access(self) var voters: {Address: Bool}

        // Escrowed vault of the creator, Holds the minimum deposit to create a ballot.
        access(self) let escrowedVault: @VotingToken.Vault

        // Initialize the ballot
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
            self.proposal = Proposal(description: description, choices: choices)
            self.creatorCapability = creatorCapability
            self.voters = {}
            self.escrowedVault <- escrowedVault
            self.ballotWeightThreshold = ballotWeightThreshold
        }

        // Allowed to vote on a ballot by providing the `choiceId` & `voterImpression`
        // i.e resource that contains the capability which would allow to read voting power of the
        // resource owner, While `choiceId` would be one of the choice that user want to choose to vote on.
        pub fun vote(choiceId: UInt16, voterImpression: @VotingToken.Vote) {
            pre {
                choiceId < 3: "Out of Index"
                voterImpression.impression.check() : "Unable to borrow the impression capability reference"
            }
            
            // Getting the resource owner
            let resourceOwner = voterImpression.owner?? panic("Resource should have the owner")

            // Verify whether resource owner already voted or not, If yes then revert to avoid double voting.
            assert(self.voters[resourceOwner.address] == nil, message: "Already voted")

            // Verify the resoruce owner should be the capability owner as well to make sure
            // capability is owned by the right owner
            assert(resourceOwner.address == voterImpression.impression.address, message: "Resource owner and capability owner should be same")
            
            // Making sure that the vote power should be greator then 0.
            let voter = voterImpression.impression.borrow() ?? panic("Unable to borrow")
            let weight = voter.getVotingPower(at: self.checkpointId)
            assert(weight > 0.0, message: "Weight should be more than 0 to register vote")
            assert(!voter.votingPowerDelegated(), message: "Voting power is delegated so not allowed to vote")
            
            // Update the state.
            self.voters[resourceOwner.address] = true
            self.proposal.weights[choiceId] = self.proposal.weights[choiceId] ?? 0.0 + weight
            emit Voted(choiceId: choiceId, whom: resourceOwner.address)
            // Destroy the vote impression resource to avoid having dangling resource.
            destroy voterImpression
        }

        // Returns the proposal details
        pub fun getProposalDetails(): ProposalDetails {
            return self.proposal.details
        }

        // Returns the list of voters
        pub fun getListOfVoters(): [Address] {
            return self.voters.keys
        }

        // Destroy the resource contain by the ballot resouurce
        destroy() {
            destroy self.escrowedVault
        }
    }

    /// Function that allows to create a ballot, Anyone can create a ballot with the caveat
    /// that the creator should staked/escrow the `minimumDesposit` amount in the created ballot.
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
            ballotWeightThreshold: 51.0 * VotingToken.totalSupply / 100.0
        )
        return <- ballot
    }


    /// Conculde the given ballot return the winning choice string or event could be emitted to keep
    /// track offchain and then destroy the ballot afterwards.
    pub fun conclude(ballot: @Ballot): String {
        var max = 0.0
        var winingChoice: UInt16 = 0
        var totalVoteWeight: UFix64 = 0.0
        for value in ballot.proposal.weights.values {
            totalVoteWeight = totalVoteWeight + value
        }
        assert(totalVoteWeight >= ballot.ballotWeightThreshold, message: "Can't conclude right now")
        for index in ballot.proposal.weights.keys {
            var concludedWeight = ballot.proposal.weights[index] ?? 0.0
            if concludedWeight > max {
                max = concludedWeight
                winingChoice = index
            }
        }
        let winningChoiceString = ballot.proposal.details.choices[winingChoice]
        destroy ballot
        return winningChoiceString
    }

    init() {
        self.minimumDeposit = 100.0
        self.ballotPath = /storage/CadenceDaoTutorialBallot
        self.ballotPublicPath = /public/CadenceDaoTutorialBallot
    }
}