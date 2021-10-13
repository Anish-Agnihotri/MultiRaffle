// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// ============ Imports ============

import "./utils/MultiRaffleTest.sol"; // MultiRaffle ds-test

/// @title MultiRaffleBenchmark
/// @author Anish Agnihotri
/// @notice Benchmarks Fisher-Yates shuffle via manual test
/// @dev Average: 2,224 gas/ticket shuffled (unoptimized)
contract MultiRaffleBenchmark is MultiRaffleTest {
    /// @notice Constant claim + variable ticket shuffle
    /// @param numTickets to shuffle
    function enterAndShuffle(uint256 numTickets) internal {
        // Create new custom raffle contract
        MultiRaffle customRaffle = new MultiRaffle(
            "Test NFT Project", // Name
            "TNFT", // Symbol
            0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445, // Chainlink key hash
            0x514910771AF9Ca656af840dff83E8264EcF986CA, // LINK token
            0xf0d54349aDdcf704F77AE15b96510dEA15cb7952, // Coordinator address
            1e17, // 0.1 eth per NFT
            10, // 10 second start time
            1000, // 1000 second end time

            // With 10000 tickets available and 10001 entries per address
            10000, 10001
        );

        // Let one user claim 10,001 tickets (> max available supply == 10,000)
        setTimeDuringRaffle();
        MultiRaffleUser user = new MultiRaffleUser(customRaffle);
        user.enterRaffle{value: 10001e17}(10001);

        setTimePostRaffle();
        user.devSetRandomness(123);

        // Claim for numTickets (allowing constant comparison)
        user.clearRaffle(numTickets);
    }

    /// @notice Shuffle 10 tickets
    function testShuffleTen() public {
        enterAndShuffle(10);
    }

    /// @notice Shuffle 20 tickets
    function testShuffleTwenty() public {
        enterAndShuffle(20);
    }

    /// @notice Shuffle 100 tickets
    function testShuffleHundred() public {
        enterAndShuffle(100);
    }

    /// @notice Shuffle 1,000 tickets
    function testShuffleOneThousand() public {
        enterAndShuffle(1000);
    }

    /// @notice Shuffle 10,000 tickets
    function testShuffleTenThousand() public {
        enterAndShuffle(10000);
    }
}