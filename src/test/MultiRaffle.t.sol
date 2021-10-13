// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// ============ Imports ============

import "./utils/MultiRaffleTest.sol"; // MultiRaffle ds-test

/// ============ Libraries ============

library Errors {
    string constant RaffleNotActive = 'Raffle not active';
    string constant RaffleEnded = 'Raffle ended';
    string constant MaxMintsForAddress = 'Max mints for address reached';
    string constant IncorrectPayment = 'Incorrect payment';
    string constant RaffleNotEnded = 'Raffle has not ended';
    string constant RaffleNoClearingNeeded = 'Raffle does not need clearing';
    string constant RaffleCleared = 'Raffle has already been cleared';
    string constant ExcessShuffle = 'Excess indices to shuffle';
    string constant NoClearingEntropy = 'No entropy to clear raffle';
    string constant RaffleNotCleared = 'Raffle has not been cleared';
    string constant TicketOutOfRange = 'Ticket is out of entries range';
    string constant TicketClaimed = 'Ticket already claimed';
    string constant TicketNotOwned = 'Ticket owner mismatch';
    string constant NoPendingReveal = 'No NFTs pending metadata reveal';
    string constant ProceedsClaimed = 'Proceeds already claimed';
}

/// ============ Functionality testing ============

contract EnterRaffleTest is MultiRaffleTest {
    /// @notice Prevent enterring before raffle active
    function testCannotEnterEarly() public {
        setTimePreRaffleStart();
        assertErrorWithMessagePayable(
            ALICE.enterRaffle,
            1,
            1e17 wei,
            Errors.RaffleNotActive
        );
    }

    /// @notice Prevent enterring after raffle has ended
    function testCannotEnterLate() public {
        setTimePostRaffle();
        assertErrorWithMessagePayable(
            ALICE.enterRaffle,
            1,
            1e17 wei,
            Errors.RaffleEnded
        );
    }

    /// @notice Prevent buying > MAX_PER_ADDRESS tickets
    function testCannotBuyExtra() public {
        setTimeDuringRaffle();
        ALICE.enterRaffle{value: 6e17 wei}(6);
        assertErrorWithMessagePayable(
            ALICE.enterRaffle,
            1,
            1e17 wei,
            Errors.MaxMintsForAddress
        );
    }

    /// @notice Previous test, with partial entries
    function testCannotBuyExtraPartial() public {
        setTimeDuringRaffle();
        for (uint256 i = 0; i < 6; i++) {
            ALICE.enterRaffle{value: 1e17 wei}(1);
        }
        assertErrorWithMessagePayable(
            ALICE.enterRaffle,
            1,
            1e17 wei,
            Errors.MaxMintsForAddress
        );
    }

    /// @notice Prevent purchasing without paying
    function testCannotBuyWithoutPaying() public {
        setTimeDuringRaffle();
        assertErrorWithMessagePayable(
            ALICE.enterRaffle,
            1,
            0,
            Errors.IncorrectPayment
        );
    }

    /// @notice Prevent purchasing with overpay
    function testCannotBuyWithOverpay() public {
        setTimeDuringRaffle();
        assertErrorWithMessagePayable(
            ALICE.enterRaffle,
            1,
            2e17 wei,
            Errors.IncorrectPayment
        );
    }

    /// @notice Purchase tickets in order and verify
    function testCanPurchaseTickets() public {
        setTimeDuringRaffle();
        ALICE.enterRaffle{value: 6e17 wei}(6);
        for (uint256 i = 0; i < 6; i++) {
            address ticketOwner = RAFFLE.raffleEntries(i);
            assertEq(address(ALICE), ticketOwner);
        }
    }

    /// @notice Purchase tickets in partial, random order and verify
    function testCanPurchaseTicketsPartial() public {
        // Enter raffle in order
        setTimeDuringRaffle();
        MultiRaffleUser[8] memory users = [ALICE, BOB, BOB, ALICE, ALICE, BOB, ALICE, BOB];
        for (uint256 i = 0; i < users.length; i++) {
            users[i].enterRaffle{value: 1e17 wei}(1);
        }

        // Assert order
        for (uint256 i = 0; i < 8; i++) {
            address ticketOwner = RAFFLE.raffleEntries(i);
            assertEq(address(users[i]), ticketOwner);
        }
    }
}

contract ClearRaffleTest is MultiRaffleTest {
    /// @notice Shuffles array with Fisher-Yates provided randomness
    /// @param addresses to shuffle
    /// @param entropy to use as randomness
    /// @param iterations to run on array
    function shuffle(
        address[] memory addresses, 
        uint256 entropy, 
        uint256 iterations
    ) internal pure returns (address[] memory) {
        // Run Fisher-Yates shuffle
        for (uint256 i = 0; i < iterations; i++) {
            // Generate a random index to select from
            uint256 randomIndex = i + entropy % (addresses.length - i);
            // Collect the value at that random index
            address randomTmp = addresses[randomIndex];
            // Update the value at the random index to the current value
            addresses[randomIndex] = addresses[i];
            // Update the current value to the value at the random index
            addresses[i] = randomTmp;
        }

        return addresses;
    }

    /// @notice Prevent clearing before raffle period conclusion
    function testCannotClearEarly() public {
        setTimeDuringRaffle();
        assertErrorWithMessageParams(ALICE.clearRaffle, 1, Errors.RaffleNotEnded);
    }

    /// @notice Prevent clearing if not needed
    function testCannotUnnessaryClean() public {
        // Fill under max supply
        standardEnterRaffle(6, 3);
        assertErrorWithMessageParams(ALICE.clearRaffle, 1, Errors.RaffleNoClearingNeeded);
    }

    /// @notice Prevent clearing cleared raffle
    function testCannotClearCleared() public {
        standardEnterRaffle(6, 6);
        ALICE.devSetRandomness(123);
        ALICE.clearRaffle(10);
        assertErrorWithMessageParams(ALICE.clearRaffle, 1, Errors.RaffleCleared);
    }

    /// @notice Prevent clearing excess indices
    function testCannotClearExcess() public {
        standardEnterRaffle(6, 6);
        assertErrorWithMessageParams(ALICE.clearRaffle, 11, Errors.ExcessShuffle);
    }

    /// @notice Prevent clearing without set entropy
    function testCannotClearNoEntropy() public {
        standardEnterRaffle(6, 6);
        assertErrorWithMessageParams(ALICE.clearRaffle, 10, Errors.NoClearingEntropy);
    }

    /// @notice Clear full raffle
    function testClearFullShuffle() public {
        // Enter raffle
        setTimeDuringRaffle();
        MultiRaffleUser[12] memory users = [
            ALICE, ALICE, ALICE, ALICE, ALICE, ALICE,
            BOB, BOB, BOB, BOB, BOB, BOB
        ];
        for (uint256 i = 0; i < users.length; i++) {
            users[i].enterRaffle{value: 1e17 wei}(1);
        }

        // Shuffle
        setTimePostRaffle();
        standardClearRaffle();

        // Generate shuffled array
        address[] memory shuffledUsers = new address[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            shuffledUsers[i] = address(users[i]);
        }
        shuffledUsers = shuffle(shuffledUsers, 123, 10);

        // Check matching shuffle
        for (uint256 i = 0; i < shuffledUsers.length; i++) {
            assertEq(shuffledUsers[i], RAFFLE.raffleEntries(i));
        }
    }

    /// @notice Clear full raffle via partial clear
    function testClearPartialShuffle() public {
        // Enter raffle
        setTimeDuringRaffle();
        MultiRaffleUser[12] memory users = [
            ALICE, ALICE, ALICE, ALICE, ALICE, ALICE,
            BOB, BOB, BOB, BOB, BOB, BOB
        ];
        for (uint256 i = 0; i < users.length; i++) {
            users[i].enterRaffle{value: 1e17 wei}(1);
        }

        // Shuffle
        setTimePostRaffle();
        ALICE.devSetRandomness(123);
        ALICE.clearRaffle(2);
        BOB.clearRaffle(5);
        ALICE.clearRaffle(3);
        
        // Generate shuffled array
        address[] memory shuffledUsers = new address[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            shuffledUsers[i] = address(users[i]);
        }
        shuffledUsers = shuffle(shuffledUsers, 123, 10);

        // Check matching shuffle
        for (uint256 i = 0; i < shuffledUsers.length; i++) {
            assertEq(shuffledUsers[i], RAFFLE.raffleEntries(i));
        }
    }
}

contract ClaimRaffleTest is MultiRaffleTest {
    uint256[] defaultTickets = [1];

    /// @notice Prevent clearing active raffle
    function testCannotClaimUnstartedRaffle() public {
        setTimePreRaffleStart();
        assertErrorWithMessageMulti(
            ALICE.claimRaffle, 
            defaultTickets, 
            Errors.RaffleNotEnded
        );
    }

    /// @notice Prevent clearing uncleared raffle
    function testCannotClaimUnclearedRaffle() public {
        standardEnterRaffle(6, 6);
        assertErrorWithMessageMulti(
            ALICE.claimRaffle,
            defaultTickets,
            Errors.RaffleNotCleared
        );
    }

    /// @notice Claim cleared raffle
    function testClaimClearedRaffle() public {
        standardFullEnterAndClear();
        uint256 prevBalance = ALICE.ETHBalance();
        ALICE.claimRaffle(ALICE.collectEntryIndexes(12));
        uint256 afterBalance = ALICE.ETHBalance();

        assertEq(ALICE.NFTCount(), 5);
        assertEq(prevBalance + 1e17 wei, afterBalance);
    }

    /// @notice Claim raffle without need for clearing
    function testClaimUnclearedRaffle() public {
        standardEnterRaffle(6, 3);
        uint256 prevBalance = ALICE.ETHBalance();
        ALICE.claimRaffle(ALICE.collectEntryIndexes(9));
        uint256 afterBalance = ALICE.ETHBalance();

        assertEq(ALICE.NFTCount(), 6);
        assertEq(prevBalance, afterBalance);
    }

    /// @notice Prevent claiming duplicate tickets
    function testCannotClaimDuplicateTickets() public {
        standardFullEnterAndClear();
        uint256[] memory duplicateTickets = new uint256[](2);
        duplicateTickets[0] = 1;
        duplicateTickets[1] = 1;
        assertErrorWithMessageMulti(
            ALICE.claimRaffle,
            duplicateTickets,
            Errors.TicketClaimed
        );
    }

    /// @notice Prevent claiming tickets not owned by you
    function testCannotClaimOthersTickets() public {
        standardFullEnterAndClear();
        assertErrorWithMessageMulti(
            ALICE.claimRaffle,
            BOB.collectEntryIndexes(12),
            Errors.TicketNotOwned
        );
    }

    /// @notice Prevent claiming tickets out of bounds
    function testCannotClaimOutOfBoundsTickets() public {
        standardFullEnterAndClear();
        uint256[] memory outBoundTickets = new uint256[](1);
        outBoundTickets[0] = 12;
        assertErrorWithMessageMulti(
            ALICE.claimRaffle,
            outBoundTickets,
            Errors.TicketOutOfRange
        );
    }

    /// @notice Prevent claiming twice
    function testCannotClaimTwice() public {
        standardFullEnterAndClear();
        uint256[] memory aliceTickets = ALICE.collectEntryIndexes(12);
        ALICE.claimRaffle(aliceTickets);
        assertErrorWithMessageMulti(
            ALICE.claimRaffle,
            aliceTickets,
            Errors.TicketClaimed
        );
    }
}

contract RevealMetadataTest is MultiRaffleTest {
    /// @notice Prevent reveailing without pending NFTs
    function testCannotRevealWithNoPending() public {
        assertErrorWithMessage(RAFFLE.revealPendingMetadata, Errors.NoPendingReveal);
    }

    /// @notice Reveals metadata in full, at once
    function testRevealPendingMetadataFull() public {
        standardFullEnterAndClear();
        ALICE.claimRaffle(ALICE.collectEntryIndexes(12));
        BOB.claimRaffle(BOB.collectEntryIndexes(12));
        ALICE.devSetRandomness(321);
        for (uint256 i = 1; i < 11; i++) {
            assertEq(
                RAFFLE.tokenURI(i),
                '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">Randomness: 321</text></svg>'
            );
        }
    }

    /// @notice Reveals metadata in partial batches
    function testRevealPendingMetadataBatches() public {
        standardFullEnterAndClear();
        ALICE.claimRaffle(ALICE.collectEntryIndexes(12));

        for (uint256 i = 0; i < 6; i++) {
            assertEq(
                RAFFLE.tokenURI(i),
                '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">No randomness assigned</text></svg>'
            );
        }
    
        ALICE.devSetRandomness(321);
        BOB.claimRaffle(BOB.collectEntryIndexes(12));
        BOB.devSetRandomness(222);

        for (uint256 i = 1; i < 11; i++) {
            if (i < 6) {
                assertEq(
                    RAFFLE.tokenURI(i),
                    '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">Randomness: 321</text></svg>'
                );
            } else {
                assertEq(
                    RAFFLE.tokenURI(i),
                    '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">Randomness: 222</text></svg>'
                );
            }
        }
    }
}

contract WithdrawProceedsTest is MultiRaffleTest {
    /// @notice Prevent withdrawing before raffle end
    function testCannotWithdrawBeforeEnd() public {
        assertErrorWithMessage(
            RAFFLE.withdrawRaffleProceeds,
            Errors.RaffleNotEnded
        );
    }

    /// @notice Prevent withdrawing twice
    function testCannotWithdrawTwice() public {
        standardFullEnterAndClear();
        uint256 prevBalance = address(this).balance;
        RAFFLE.withdrawRaffleProceeds();
        uint256 afterBalance = address(this).balance;
        assertEq(prevBalance + 10e17, afterBalance);
        assertErrorWithMessage(
            RAFFLE.withdrawRaffleProceeds,
            Errors.ProceedsClaimed
        );
    }

    /// @notice Test max withdraw
    function testMaxWithdraw() public {
        standardFullEnterAndClear();
        uint256 prevBalance = address(this).balance;
        RAFFLE.withdrawRaffleProceeds();
        uint256 afterBalance = address(this).balance;
        assertEq(prevBalance + 10e17, afterBalance);
    }

    /// @notice Test partial withdraw
    function testPartialWithdraw() public {
        standardEnterRaffle(3, 3);
        uint256 prevBalance = address(this).balance;
        RAFFLE.withdrawRaffleProceeds();
        uint256 afterBalance = address(this).balance;
        assertEq(prevBalance + 6e17, afterBalance);
    }
}