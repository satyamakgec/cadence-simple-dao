import VotingToken from "../../contracts/VotingToken.cdc"


transaction {

    let capabilityReference: Capability<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance, VotingToken.Delegation, VotingToken.VotingPower}>

    prepare(signer: AuthAccount) {

        // Step 1: Create an account that can successfully receive the voting token
        let emptyVault <- VotingToken.createEmptyVault()
        signer.save<@VotingToken.Vault>(<- emptyVault, to: VotingToken.vaultPath)

        log("Empty vault successfully stored")

        // Step 2: Create a public capability so anybody can use it for the depositing the tokens init.
        self.capabilityReference = signer.link<&VotingToken.Vault{VotingToken.Recevier, VotingToken.Balance, VotingToken.Delegation, VotingToken.VotingPower}>(VotingToken.vaultPublicPath, target: VotingToken.vaultPath)

        log("Public capability successfully created")

    }

    post {
        self.capabilityReference.check() : "Vault Receiver Reference was not created correctly"
    }


}
