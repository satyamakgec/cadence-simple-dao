import VotingToken from "../../contracts/VotingToken.cdc"


transaction(delegatee: Address) {

    var delegationReceiverCapRef: Capability<&VotingToken.Vault{VotingToken.Delegation, VotingToken.VotingPower}>

    var delegaterCapRef: Capability<&VotingToken.Vault{VotingToken.DelegateVotingPower, VotingToken.VotingPower}>

    prepare(signer: AuthAccount) {

        self.delegationReceiverCapRef = getAccount(delegatee)
                                            .getCapability<&VotingToken.Vault{VotingToken.Delegation, VotingToken.VotingPower}>(from: VotingToken.vaultPublicPath)
                                            .check() : "Capability doesn't exists"

        self.delegaterCapRef = signer.borrow<&VotingToken.Vault{VotingToken.DelegateVotingPower, VotingToken.VotingPower}>(from: VotingToken.vaultPath) ??
                                panic("Not able to borrow")

    }

    execute {
        self.delegationReceiverCapRef.delegate(cap: self.delegaterCapRef)
    }

    post {
        assert(self.delegaterCapRef.getVotingPower(at: VotingToken.checkpointId) == 0.0, message: "Unsuccessful delegation happen")
    }
}