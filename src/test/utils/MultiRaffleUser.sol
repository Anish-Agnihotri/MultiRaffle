// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// ============ Imports ============

import "../../MultiRaffle.sol"; // MultiRaffle
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol"; // OZ: ERC721 recipient

/// @title MultiRaffleUser
/// @author Anish Agnihotri
/// @notice Mock user to test interacting with MultiRaffle
contract MultiRaffleUser is ERC721Holder {

    /// ============ Immutable storage ============

    /// @dev Raffle contract
    MultiRaffle immutable internal RAFFLE;

    /// ============ Constructor ============

    /// @notice Creates a new MutliRaffleUser
    /// @param _RAFFLE contract
    constructor(MultiRaffle _RAFFLE) {
        RAFFLE = _RAFFLE;
    }

    /// ============ Helper functions ============

    /// @notice Returns ETH balance of user
    function ETHBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Returns number of NFTs owned by user
    function NFTCount() public view returns (uint256) {
        return RAFFLE.balanceOf(address(this));
    }

    /// @notice Returns ownership status of NFT id
    /// @param id NFT id to check
    function NFTOwned(uint256 id) public view returns (bool) {
        return RAFFLE.ownerOf(id) == address(this);
    }

    /// @notice Collects indices of winning tickets by user
    /// @param totalEntries number of entries to iterate
    function collectEntryIndexes(uint256 totalEntries) 
        public
        view
        returns (uint256[] memory) 
    {
        uint256 currIndex = 0;
        uint256[] memory indices = new uint256[](
            RAFFLE.entriesPerAddress(address(this))
        );
        for (uint256 i = 0; i < totalEntries; i++) {
            address ticketOwner = RAFFLE.raffleEntries(i);
            if (ticketOwner == address(this)) {
                indices[currIndex] = i;
                currIndex++;
            }
        }
        return indices;
    }

    /// ============ Inherited Functionality ============

    /// @notice Enters raffle with numTickets entries
    /// @param numTickets Number of raffle entries
    function enterRaffle(uint256 numTickets) payable public {
        RAFFLE.enterRaffle{value: msg.value}(numTickets);
    }

    /// @notice Allows partially or fully clearing a raffle (if needed)
    /// @param numShuffles Number of indices to shuffle (max = remaining)
    function clearRaffle(uint256 numShuffles) public {
        RAFFLE.clearRaffle(numShuffles);
    }

    /// @notice Allows user to mint NFTs for winning tickets or claim refund for losing tickets
    /// @param tickets indices of all raffle tickets owned by caller
    function claimRaffle(uint256[] calldata tickets) public {
        RAFFLE.claimRaffle(tickets);
    }

    /// @notice Allows overriding Chainlink VRF callback to set randomness
    /// @param randomness to update
    function devSetRandomness(uint256 randomness) public {
        RAFFLE.fulfillRandomness(bytes32("override"), randomness);
    }

    /// @notice Allows receiving ETH
    receive() external payable {}
}