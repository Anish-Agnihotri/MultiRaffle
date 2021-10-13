// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// ============ Imports ============

import "./Hevm.sol"; // hevm
import "./DSTestExtended.sol"; // DSTest + more assertions
import "./MultiRaffleUser.sol"; // Raffle user
import "../../MultiRaffle.sol"; // MultiRaffle

/// @title MultiRaffleTest
/// @author Anish Agnihotri
/// @notice Base test to inherit functionality from. Deploys relevant contracts.
contract MultiRaffleTest is DSTestExtended {

    /// ============ Storage ============

    /// @dev Raffle setup
    MultiRaffle internal RAFFLE;
    /// @dev Hevm setup
    Hevm constant internal HEVM = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    /// @dev Raffle user — Alice
    MultiRaffleUser internal ALICE;
    /// @dev Raffle user — Bob
    MultiRaffleUser internal BOB;

    /// ============ Tests setup ============

    function setUp() public virtual {
        // Start at timestamp 0
        HEVM.warp(0);

        // Setup raffle
        RAFFLE = new MultiRaffle(
            "Test NFT Project", // Name
            "TNFT", // Symbol
            0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445, // Chainlink key hash
            0x514910771AF9Ca656af840dff83E8264EcF986CA, // LINK token
            0xf0d54349aDdcf704F77AE15b96510dEA15cb7952, // Coordinator address
            1e17, // 0.1 eth per NFT
            10, // 10 second start time
            1000, // 1000 second end time
            10, // 10 available NFTs
            6 // 6 max raffle entries per address
        );

        // Setup raffle users
        ALICE = new MultiRaffleUser(RAFFLE);
        BOB = new MultiRaffleUser(RAFFLE);
    }

    /// @notice Allows receiving ETH
    receive() external payable {}

    /// ============ Helper functions ============

    /// @notice Sets time to before raffle starts
    function setTimePreRaffleStart() public {
        HEVM.warp(0);
    }

    /// @notice Sets time to during the raffle
    function setTimeDuringRaffle() public {
        HEVM.warp(50);
    }

    /// @notice Sets time to after raffle conclusion
    function setTimePostRaffle() public {
        HEVM.warp(1050);
    }

    /// @notice Enters Alice + Bob with max. 6 tickets each
    /// @param numAliceTickets to purchase
    /// @param numBobTickets to purchase
    function standardEnterRaffle(
        uint256 numAliceTickets, 
        uint256 numBobTickets
    ) public {
        setTimeDuringRaffle();
        ALICE.enterRaffle{value: 1e17 * numAliceTickets}(numAliceTickets);
        BOB.enterRaffle{value: 1e17 * numBobTickets}(numBobTickets);
        setTimePostRaffle();
    }

    function standardClearRaffle() public {
        ALICE.devSetRandomness(123);
        ALICE.clearRaffle(10);
    }

    /// @notice Enters Alice + Bob into raffle and shuffles
    function standardFullEnterAndClear() public {
        standardEnterRaffle(6, 6);
        standardClearRaffle();
    }
}