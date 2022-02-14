
pub contract VotingToken {

    pub var totalSupply: UFix64

    /// Checkpoint is the Id at which the snapshot of the balance taken.
    /// Ex - if Alice balance is 10 before taking the snapshot and just after that new checkpoint get
    /// created then at new checkpointId alice balance get recorded to be 10. So it always have the balance
    /// that is recorded last for a given checkpoint.
    pub var checkpointId: UInt16
    
    /// Recevier interface to facilitate the working of the desposit in vault.
    pub resource interface Recevier {
        pub fun deposit(vault: @Vault)
    }

    /// Provider interface to facilitate the working of the withdraw of vault.
    pub resource interface Provider {
        pub fun withdraw(amount: UFix64): @Vault
    }

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
    }

    /// Resource that allows to delegate the voting power to another token holder.
    /// Ex - Alice and Bob are the 2 token holder of the `VotingToken` and Alice don't want
    /// to participate in the governance system then she can delegate her voting power to the Bob
    /// using the `delegate` function. So Alice calls `delegate()` function of the bob to appoint him
    /// the delegate of her voting power.
    pub resource interface Delegation {
        pub fun delegate(capRef: Capability<&AnyResource{DelegateVotingPower, VotingPower}>)
    }

    /// Resource that allows to facilitate the switch over the voting power.
    /// If `true` as status get passed then given account delegating there voting power to
    /// the given capability and in future can't vote using there voting power until delegation get revoked.
    pub resource interface DelegateVotingPower {
        pub fun delegateVotingPower(status: Bool, delegateTo: Capability<&AnyResource{VotingPower}>)
    }

    pub resource Vault: Provider, Recevier, Balance, VotingPower, DelegateVotingPower {
        
        pub var balance: UFix64

        /// Variable to know whether the user voting power is delegate or it is allowed to vote itself.
        /// Ex - if it is set `true` then voting power is delegated to `delegateTo` capability.
        pub var isVotingPowerDelegated: Bool

        /// Optional variable which contains the capability of the delegate.
        pub var delegateTo: Capability<&AnyResource{VotingPower}>?

        /// It the checkpoint Id at which the last snapshot taken for the given vault.
        pub var lastCheckpointId: UInt16

        /// No. of maximum delegate that the vault owner can be to other token holders.
        pub let maximumDelegate: UInt16


        /// Dictionary to keep track of the voting power for a given checkpoint.
        access(self) var votingPower: {UInt16: UFix64}

        /// Array list to contain the capabilities whom the vault owner is the delegate of.
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

        /// Function to deposit the vault.
        /// It also going to create the checkpoint/snapshot for a current checkpointId.
        pub fun deposit(vault: @Vault) {
            pre {
                vault.balance > 0.0 : "Balance should be greater than 0"
            }
            self.balance = self.balance + vault.balance
            self._updateCheckpointBalances()
            destroy vault
        }

        /// Function to withdraw the vault.
        /// It also going to create the checkpoint/snapshot for a current checkpointId.
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
        pub fun delegate(cap: Capability<&AnyResource{DelegateVotingPower,VotingPower}>) {
            let capRef = cap.borrow()?? panic("Unable to borrow the ref")
            if self.delegateeOf.length > Int(self.maximumDelegate) {
                panic("Delegatee limit reached")
            }
            capRef.delegateVotingPower(status: true, delegateTo: cap)
            self.delegateeOf.append(cap)
        }

        /// Switch to know the owner of the delegate power.
        pub fun delegateVotingPower(status: Bool, delegateTo: Capability<&AnyResource{VotingPower}>) {
            self.isVotingPowerDelegated = status
            self.delegateTo = delegateTo
        }

        /// Give the voting power at the given checkpoint Id.
        pub fun getVotingPower(at: UInt16): UFix64 {
            pre {
                at <= VotingToken.checkpointId : "Can not query the voting power to a non existent block number"
            }
            if self.isVotingPowerDelegated {
                return 0.0
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

    pub fun createEmptyVault(): @Vault {
        return <- create Vault(balance: 0.0)
    }

    pub resource Minter {

        pub fun mint(amount: UFix64, recepient: Capability<&AnyResource{Recevier}>)  {
            let ref = recepient.borrow()?? panic("Not able to borrow")
            let token <- create Vault(balance:amount)
            VotingToken.totalSupply = VotingToken.totalSupply + amount
            ref.deposit(vault: <-token)
        }

    }

    pub resource Adminstrator {
        /// Allow administrator to create the checkpoint.
        pub fun createCheckpoint() {
            VotingToken.checkpointId = VotingToken.checkpointId + 1
        } 
    }

    init() {
        self.totalSupply = 0.0
        self.checkpointId = 0
        let vault <- self.createEmptyVault()
        self.account.save(<-vault, to: /storage/CadenceVotingTokenTutorialVault)
    }

}