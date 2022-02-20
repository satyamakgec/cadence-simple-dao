import VotingToken from "../../contracts/VotingToken.cdc"


transaction(receiver1: Address, receiver2: Address) {

    let minterRef: Capability<&VotingToken.Minter>

    var receiverCapabilityRef1: Capability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}>

    var receiverCapabilityRef2: Capability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}>

    prepare(signer: AuthAccount) {

        // Step 1: Borrow the minter private capability to mint the funds to the given receivers.
        self.minterRef = signer.borrow<&VotingToken.Minter>(from: VotingToken.minterResourcePath)?? panic("Unable to borrow the minter reference")

        // Step 2: Create capabilities ref of the accounts that get received the fungible tokens
        self.receiverCapabilityRef1 = getAccount(receiver1)
                                    .getCapability()<&VotingToken.Vault{VotingToken.Recevier, VotingToken, Balance}>(from: VotingToken.vaultPublicPath)
                                    .check() : "Capability doesn't exists"
        self.receiverCapabilityRef2 = getAccount(receiver2)
                                    .getCapability()<&VotingToken.Vault{VotingToken.Recevier, VotingToken, Balance}>(from: VotingToken.vaultPublicPath)
                                    .check() : "Capability doesn't exists"

        log("Minter resource reference get borrowed successfully")

    }

    execute {
        // Mint 500 Voting tokens to the recepient 1
        self.minterRef.mint(amount: 500.0, recepient: self.receiverCapabilityRef1)

        log("Minted 500 tokens to receiver 1")

        // Mint 100 Voting tokens to the recepient 2
        self.minterRef.mint(amount: 100.0, recepient: self.receiverCapabilityRef2)

        log("Minted 100 tokens to receiver 1")
    }

    post {
        // Check whether the receviers received there respective balances
        assert(self.receiverCapabilityRef1.balance == 500.0, message: "Failed to mint correct balance amount")
        assert(self.receiverCapabilityRef2.balance == 100.0, message: "Failed to mint correct balance amount")
    }
}