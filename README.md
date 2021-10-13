<p align="center">
  <h1 align="center">MultiRaffle</h1>
</p>
<p align="center">
<b><a href="https://github.com/anish-agnihotri/MultiRaffle#About">About</a></b>
|
<b><a href="https://github.com/anish-agnihotri/MultiRaffle#Implementation">Implementation</a></b>
|
<b><a href="https://github.com/anish-agnihotri/MultiRaffle#License">License</a></b>
</p>

# About

MultiRaffle is an **unaudited, unoptimized** NFT distribution reference, implenting a randomized multi-winner raffle and randomized on-chain metadata generation.

It allows `operators` to quickly deploy an NFT distribution that allows `users` to purchase refundable raffle tickets, potentially win NFTs, and randomly assign metadata to these NFTs via [Chainlink VRF](https://docs.chain.link/docs/chainlink-vrf/).

# Implementation

1. Each raffle begins with an `operator` assigning constants including `NFT Name`, `NFT Symbol`, `Mint Cost (per NFT)`, `Raffle Start Time`, `Raffle End Time`, `Available NFT Supply`, and `Max Raffle Entries per Address`.
2. Then, for the period that the raffle is active, `users` can enter the raffle and claim up to `Max Raffle Entries per Address` tickets.
3. Once the raffling period is finished, the NFTs can be distributed among winning tickets. If there are fewer purchased tickets than the `Available NFT Supply`, no clearing is required. Else, anyone can and must call `clearRaffle` (either in partial steps socializing gas cost, or all at once) to forward [Fisher-Yates shuffle](https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle) the raffle entries and choose winners.

```solidity
// Fisher-Yates shuffle across set of raffle tickets
for (uint256 i = shuffledCount; i < shuffledCount + numShuffles; i++) {
    // Generate a random index to select from
    uint256 randomIndex = i + entropy % (raffleEntries.length - i);
    // Collect the value at that random index
    address randomTmp = raffleEntries[randomIndex];
    // Update the value at the random index to the current value
    raffleEntries[randomIndex] = raffleEntries[i];
    // Update the current value to the value at the random index
    raffleEntries[i] = randomTmp;
}
```

4. Once winning tickets have been determined, `users` can claim either NFTs for their winning tickets or a refund for their losing tickets.
5. Finally, once `users` have their NFTs, they can choose to reveal metadata. This will randomly reveal the metadata for all NFTs pending metadata.

```solidity
// Metadata for range of tokenIds (batch applied to startIndex - endIndex)
struct Metadata {
    // Starting index (inclusive)
    uint256 startIndex;
    // Ending index (exclusive)
    uint256 endIndex;
    // Randomness for range of tokens
    uint256 entropy;
}
```

# Build and Test

```bash
# Collect repo
git clone https://github.com/anish-agnihotri/MultiRaffle
cd MultiRaffle

# Checkout tests branch to modify contract to mock Chainlink
git checkout -t origin/tests

# Run tests
make
make test
```

# Installing the toolkit

If you do not have DappTools already installed, you'll need to run the commands below:

## Install Nix

```bash
# User must be in sudoers
curl -L https://nixos.org/nix/install | sh

# Run this or login again to use Nix
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

## Install DappTools

```bash
curl https://dapp.tools/install | sh
```

# License

[GNU Affero GPL v3.0](https://github.com/Anish-Agnihotri/MultiRaffle/blob/master/LICENSE)

# Credits

- [@gakonst/lootloose](https://github.com/gakonst/lootloose) for DappTools info + inspiration
- ds-test, OZ, Chainlink for inherited libraries

# Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. Paradigm is not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
