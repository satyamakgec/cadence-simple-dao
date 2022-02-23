import VotingToken from "../../contracts/VotingToken.cdc"

/// Transfer tokens from signer to the recepient
transaction(recepient: Address) {

    var senderRef: &VotingToken.Vault

    var receiverCapRef: &VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}

    prepare(signer: AuthAccount) {

        self.senderRef = signer.borrow<&VotingToken.Vault>(from: VotingToken.vaultPath)
                     ?? panic("Unable to borrow the sender capability reference")

        let receiverCap = getAccount(recepient)
                                .getCapability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}>(VotingToken.vaultPublicPath)
        if !receiverCap.check() {
            panic("Capability doesn't exists")
        }
        self.receiverCapRef = receiverCap.borrow()!
    }

    execute {
        let temporaryVault <- self.senderRef.withdraw(amount: 50.0)
        self.receiverCapRef.deposit(vault: <-temporaryVault)

        log("Updated balance of the receiver")
        log(self.receiverCapRef.balance)
    }
}
 