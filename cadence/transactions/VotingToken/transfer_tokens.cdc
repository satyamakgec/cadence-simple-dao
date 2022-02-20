import VotingToken from "../../contracts/VotingToken.cdc"

transaction(recepient: Address) {

    var senderRef: Capability<&VotingToken.Vault>

    var receiverCapRef: Capability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}>

    prepare(signer: AuthAccount) {

        self.senderRef = signer.borrow<&VotingToken.Vault>(from: VotingToken.vaultPath)

        self.receiverCapRef = getAccount(recepient)
                                .getCapability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}>()
                                .check() : "Capability doesn't exists"
    }

    execute {
        let temporaryVault <- self.senderRef.withdraw(amount: 50.0)
        self.receiverCapRef.deposit(vault: <-temporaryVault)

        log("Updated balance of the receiver")
        log(self.receiverCapRef.balance)
    }
}