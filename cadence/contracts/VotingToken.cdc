/// It is extension of the Fungible token standard
/// Goal here to showcase the possibilities in cadence language to design
/// the governance token, It has the minimum functionality of being a governance token
/// while it can be extended more to support more shposticated edge cases.
/// Note - It is not a production ready code
pub contract VotingToken {

    /// It is a good practice to store the paths in a contract variable instead of
    /// hanging strings in the contract, It helps avoid the human mistake of re-writing the storage paths
    /// again and again.
    ///
    /// Storage path where vault resource get stored.
    pub let vaultPath: StoragePath

    /// Public path where the vault public capability get stored
    pub let vaultPublicPath: PublicPath

    /// Storage Path that holds the minter resource
    pub let minterResourcePath: StoragePath

    /// Storage Path that holds the administrator resource
    pub let administratorResourcePath: StoragePath

    /// Total supply of the voting token
    pub var totalSupply: UFix64

    /// Checkpoint is the Id at which the snapshot of the balance taken.
    /// Ex - if Alice balance is 10 before taking the snapshot and just after that new checkpoint get
    /// created then at new checkpointId alice balance get recorded to be 10. So it always have the balance
    /// that is recorded last for a given checkpoint.
    pub var checkpointId: UInt16

    /// Event emitted when someone (i.e `of`) calls the `delegate` function to make 
    /// vault owner delegate of the `of`.
    pub event Delegated(of: Address)

    /// Event emitted when new checkpoint get created by the administrator.
    pub event CheckPointCreated(newCheckpointId: UInt16)
    
    /// Recevier interface to facilitate the working of the desposit in vault.
    pub resource interface Recevier {
        pub fun deposit(vault: @Vault)
    }

    /// Provider interface to facilitate the working of the withdraw of vault.
    pub resource interface Provider {
        pub fun withdraw(amount: UFix64): @Vault
    }

    /// Resource interface for balance
    pub resource interface Balance {
        pub var balance: UFix64

        init(balance: UFix64) {
            post {
                self.balance == balance:
                    "Balance must be initialized to the initial balance"
            }
        }
    }

    /// Resource to provide the voting power at a given `checkpointId`.
    pub resource interface VotingPower {
        pub fun getVotingPower(at: UInt16): UFix64
        pub fun votingPowerDelegated(): Bool
    }

    /// Resource that allows to delegate the voting power to another token holder.
    /// Ex - Alice and Bob are the 2 token holder of the `VotingToken` and Alice don't want
    /// to participate in the governance system then she can delegate her voting power to the Bob
    /// using the `delegate` function. So Alice calls `delegate()` function of the bob to appoint him
    /// the delegate of her voting power.
    pub resource interface Delegation {
        pub fun delegate(cap: Capability<&AnyResource{DelegateVotingPower, VotingPower}>)
    }

    /// Resource that allows to facilitate the switch over the voting power.
    /// If `true` as status get passed then given account delegating there voting power to
    /// the given capability and in future can't vote using there voting power until delegation get revoked.
    pub resource interface DelegateVotingPower {
        pub fun delegateVotingPower(status: Bool, delegateTo: Address)
    }

    /// Introduced the new resource because we don't want to allow someone else to vote
    /// using someone else voting power without delegation.
    /// User should create a resource object using `createVoteImpression()` and pass the public
    /// capability to read the voting power.
    /// It is only a workaround to make it permissioned, It could be improve with the better design.
    /// Note - This should always be a private resource
    pub resource Vote {
        // Hold the capability that will allow to get the voting power of the resource owner.
        pub let impression: Capability<&AnyResource{VotingPower}>

        init(impression: Capability<&AnyResource{VotingPower}>) {
            self.impression = impression
        }
    }

    pub resource Vault: Provider, Recevier, Balance, VotingPower, DelegateVotingPower, Delegation {
        
        // Amount of tokens hold by the vault
        pub var balance: UFix64

        // Variable to know whether the user voting power is delegate or it is allowed to vote itself.
        // Ex - if it is set `true` then voting power is delegated to `delegateTo` address.
        pub var isVotingPowerDelegated: Bool

        // Optional address to hold whom can act as the delegate of the vault owner.
        access(self) var delegateTo: Address?

        // It the checkpoint Id at which the last snapshot taken for the given vault.
        pub var lastCheckpointId: UInt16

        // No. of maximum delegate that the vault owner can be to other token holders.
        // In the current implementation it is set to 10
        pub let maximumDelegate: UInt16

        // Dictionary to keep track of the voting power for a given checkpoint.
        access(self) var votingPower: {UInt16: UFix64}

        // Array list to contain the capabilities whom the vault owner is the delegate of.
        access(self) var delegateeOf: [Capability<&AnyResource{VotingPower}>]

        init(balance: UFix64) {
            self.balance = balance
            self.votingPower = {}
            self.isVotingPowerDelegated = false
            self.lastCheckpointId = VotingToken.checkpointId
            self.delegateeOf = []
            self.maximumDelegate = 10
            self.delegateTo = nil
        }

        // Function to deposit the vault.
        // It also going to create the checkpoint/snapshot for a current checkpointId.
        pub fun deposit(vault: @Vault) {
            pre {
                vault.balance > 0.0 : "Balance should be greater than 0"
            }
            self.balance = self.balance + vault.balance
            self._updateCheckpointBalances()
            destroy vault
        }

        // Function to withdraw the vault.
        // It also going to create the checkpoint/snapshot for a current checkpointId.
        pub fun withdraw(amount: UFix64): @Vault {
            pre {
                amount > 0.0 : "Zero amount is not allowed"
            }
            self.balance = self.balance - amount
            self._updateCheckpointBalances()
            let token <- create Vault(balance: amount)
            return <- token
        }

        access(self) fun _updateCheckpointBalances() {
            let currentCheckpointId = VotingToken.checkpointId
            self.votingPower[currentCheckpointId] = self.balance
        }

        /// Allow to delegate the voting power of a given capability.
        /// Ex - User A wants to delegate the voting power to User B then User A would call
        /// delegate function of the User B by passing its own capability.
        /// Note - User B can't be a delegate of anymore than the `maximumDelegate`.
        pub fun delegate(cap: Capability<&AnyResource{DelegateVotingPower, VotingPower}>) {
            pre {
                cap.check() : "Not a valid capability"
            }
            let capRef = cap.borrow()?? panic("Unable to borrow the ref")
            assert(self.delegateeOf.length > Int(self.maximumDelegate), message:"Delegatee limit reached")
            capRef.delegateVotingPower(status: true, delegateTo: self.owner!.address)
            self.delegateeOf.append(cap)
            emit Delegated(of: cap.address)
        }

        /// Switch to know the owner of the delegate power.
        pub fun delegateVotingPower(status: Bool, delegateTo: Address) {
            self.isVotingPowerDelegated = status
            self.delegateTo = delegateTo
        }

        /// Tells whether the vault owner delegated the voting power or not.
        pub fun votingPowerDelegated() : Bool {
            return self.isVotingPowerDelegated
        }

        /// Give the voting power at the given checkpoint Id.
        pub fun getVotingPower(at: UInt16): UFix64 {
            pre {
                at <= VotingToken.checkpointId : "Can not query the voting power to a non existent block number"
            }
            var tempPower: UFix64 = 0.0;
            for cap in self.delegateeOf {
                let capRef = cap.borrow()?? panic("Unable to borrow the ref")
                tempPower = tempPower + capRef.getVotingPower(at: at)
            }
            var selfVotingPower : UFix64 = 0.0;
            if at >= self.lastCheckpointId {
                selfVotingPower = self.votingPower[self.lastCheckpointId] ?? panic("Should have the value at last checkpoint")
            } else {
                // TODO: Improve the logic here to calculate the voting power for a given checkpoint.
                self.votingPower[at] ?? 0.0
            }
            return  selfVotingPower + tempPower
        }
    }

    /// Anyone can call this function and create empty vault.
    pub fun createEmptyVault(): @Vault {
        return <- create Vault(balance: 0.0)
    }

    /// Anyone can call this function and create voteImpression.
    pub fun createVoteImpression(impression: Capability<&AnyResource{VotingPower}>): @Vote {
        return <- create Vote(impression: impression)
    }

    pub resource Minter {

        pub fun mint(amount: UFix64, recepient: Capability<&AnyResource{Recevier}>)  {
            pre {
                recepient.check() : "Not a valid capability"
                amount > 0.0 : "Not allowed to mint 0 amount"
            }
            let ref = recepient.borrow()?? panic("Not able to borrow")
            let token <- create Vault(balance:amount)
            VotingToken.totalSupply = VotingToken.totalSupply + amount
            ref.deposit(vault: <-token)
        }

    }

    /// Administrator resource that can create checkpoint
    pub resource Administrator {
        /// Allow administrator to create the checkpoint.
        pub fun createCheckpoint() {
            VotingToken.checkpointId = VotingToken.checkpointId + 1
            emit CheckPointCreated(newCheckpointId: VotingToken.checkpointId)
        } 
    }

    init() {
        self.vaultPath = /storage/CadenceVotingTokenTutorialVault
        self.vaultPublicPath = /public/CadenceVotingTokenTutorialVaultPublic
        self.minterResourcePath = /storage/CadenceVotingTokenTutorialMinter
        self.administratorResourcePath = /storage/CadenceVotingTokenTutorialAdministrator
        self.totalSupply = 0.0
        self.checkpointId = 0
        let vault <- self.createEmptyVault()
        self.account.save(<- vault, to: self.vaultPath)
        self.account.save(<- create Minter(), to: self.minterResourcePath)
        self.account.save(<- create Administrator(), to: self.administratorResourcePath)

        // Creating the private capabilities so it can be shared with different accounts
        self.account.link<&VotingToken.Minter>(/private/CadenceVotingTokenTutorialMinterPrivate, target: self.minterResourcePath)
        self.account.link<&VotingToken.Administrator>(/private/CadenceVotingTokenTutorialAdministratorPrivate, target: self.administratorResourcePath)
    }

}