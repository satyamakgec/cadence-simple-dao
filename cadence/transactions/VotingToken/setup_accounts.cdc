import VotingToken from "../../contracts/VotingToken.cdc"

/// Accounts got funded with some initial balance
transaction(receiver1: Address, receiver2: Address) {

    let minterRef: &VotingToken.Minter

    var receiverCapability1: Capability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}>

    var receiverCapability2: Capability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}>

    prepare(signer: AuthAccount) {

        // Step 1: Borrow the minter private capability to mint the funds to the given receivers.
        self.minterRef = signer.borrow<&VotingToken.Minter>(from: VotingToken.minterResourcePath)?? panic("Unable to borrow the minter reference")

        // Step 2: Create capabilities ref of the accounts that get received the fungible tokens
        self.receiverCapability1 = getAccount(receiver1)
                                    .getCapability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}>(VotingToken.vaultPublicPath)
        if !self.receiverCapability1.check() {
            panic("Doesn't have the capability at given path")
        }
        self.receiverCapability2 = getAccount(receiver2)
                                    .getCapability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance}>(VotingToken.vaultPublicPath)
        if !self.receiverCapability2.check() {
            panic("Doesn't have the capability at given path")
        }
        log("Minter resource reference get borrowed successfully")

    }

    execute {
        // Mint 500 Voting tokens to the recepient 1
        self.minterRef.mint(amount: 500.0, recepient: self.receiverCapability1)

        log("Minted 500 tokens to receiver 1")

        // Mint 100 Voting tokens to the recepient 2
        self.minterRef.mint(amount: 100.0, recepient: self.receiverCapability2)

        log("Minted 100 tokens to receiver 1")
    }

    post {
        // Check whether the receviers received there respective balances
        self.receiverCapability1.borrow()!.balance == 500.0 : "Failed to mint correct balance amount"
        self.receiverCapability2.borrow()!.balance == 100.0 : "Failed to mint correct balance amount"
    }
}