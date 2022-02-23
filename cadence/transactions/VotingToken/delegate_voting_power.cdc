import VotingToken from "../../contracts/VotingToken.cdc"

/// Allow to delegate the voting power
transaction(delegatee: Address) {

    var delegationReceiverCapRef : &VotingToken.Vault{VotingToken.Delegation, VotingToken.VotingPower}

    var delegaterCap: Capability<&VotingToken.Vault{VotingToken.DelegateVotingPower, VotingToken.VotingPower}>

    let delegaterCapRef: &VotingToken.Vault{VotingToken.VotingPower}

    prepare(signer: AuthAccount) {

        self.delegationReceiverCapRef = getAccount(delegatee)
                                    .getCapability<&VotingToken.Vault{VotingToken.Delegation, VotingToken.VotingPower}>(VotingToken.vaultPublicPath)
                                    .borrow() ?? panic("Unable to borrow the delegation receiver capability reference")

        self.delegaterCap = signer.link<&VotingToken.Vault{VotingToken.DelegateVotingPower, VotingToken.VotingPower}>(/private/CadenceVotingTokenTutorialVotingPowerDelegation, target: /storage/vaultPath)!
        self.delegaterCapRef = signer.getCapability<&VotingToken.Vault{VotingToken.VotingPower}>(VotingToken.vaultPublicPath)
                                .borrow() ?? panic("Unable to borrow public capability of the delegator to receive the voting power")
    }

    execute {
        self.delegationReceiverCapRef.delegate(cap: self.delegaterCap)
    }

    post {
        self.delegaterCapRef.votingPowerDelegated() : "Unsuccessful delegation happen"
    }
}