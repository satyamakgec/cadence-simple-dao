
pub contract VotingToken {

    pub var totalSupply: UFix64

    pub var checkpointId: UInt16

    pub resource interface Recevier {
        pub fun deposit(vault: @Vault)
    }

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

    pub resource interface VotingPower {
        pub fun getVotingPower(at: UInt16): UFix64
    }

    pub resource interface Delegation {
        pub fun delegateTo(capRef: Capability<&AnyResource{DelegateVotingPower, VotingPower}>, status: Bool)
    }

    pub resource interface DelegateVotingPower {
        pub fun delegateVotingPower(status: Bool)
    }

    pub resource Vault: Provider, Recevier, Balance, VotingPower, DelegateVotingPower {
        
        pub var balance: UFix64

        pub var isVotingPowerDelegated: Bool

        pub var lastCheckpointId: UInt16

        pub let maximumDelegate: UInt16

        access(self) var votingPower: {UInt16: UFix64}

        access(self) var delegateeOf: [Capability<&AnyResource{VotingPower}>]

        init(balance: UFix64) {
            self.balance = balance
            self.votingPower = {}
            self.isVotingPowerDelegated = false
            self.lastCheckpointId = VotingToken.checkpointId
            self.delegateeOf = []
            self.maximumDelegate = 10
        }

        pub fun deposit(vault: @Vault) {
            pre {
                vault.balance > 0.0 : "Balance should be greater than 0"
            }
            self.balance = self.balance + vault.balance
            self._updateCheckpointBalances()
            destroy vault
        }

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

        pub fun delegateTo(cap: Capability<&AnyResource{DelegateVotingPower,VotingPower}>, status: Bool) {
            let capRef = cap.borrow()?? panic("Unable to borrow the ref")
            if self.delegateeOf.length > Int(self.maximumDelegate) {
                panic("Delegatee limit reached")
            }
            capRef.delegateVotingPower(status: status)
            self.delegateeOf.append(cap)
        }

        pub fun delegateVotingPower(status: Bool) {
            self.isVotingPowerDelegated = status
        }

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