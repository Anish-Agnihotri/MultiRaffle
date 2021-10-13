// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// ============ Imports ============

import "ds-test/test.sol"; // ds-test

/// @title DSTestExtended
/// @author Anish Agnihotri
/// @notice Extends DSTest with more generic assertions for revert checks
contract DSTestExtended is DSTest {
    /// @notice Calls function and checks for matching revert message
    /// @param erroringFunction to call
    /// @param message to check against revert error string
    function assertErrorWithMessage(
        function() external erroringFunction,
        string memory message
    ) internal {
        try erroringFunction() { 
            fail();
        } catch Error(string memory error) {
            // Assert revert error matches expected message
            assertEq(error, message);
        }
    }

    /// @notice Calls function and checks for matching revert message
    /// @param erroringFunction to call
    /// @param param to pass to function
    /// @param message to check against revert error string
    function assertErrorWithMessageParams(
        function(uint256) external erroringFunction,
        uint256 param,
        string memory message
    ) internal {
        try erroringFunction(param) { 
            fail();
        } catch Error(string memory error) {
            // Assert revert error matches expected message
            assertEq(error, message);
        }
    }

    /// @notice Calls function and checks for matching revert message
    /// @param erroringFunction to call
    /// @param params to pass to function
    /// @param message to check against revert error string
    function assertErrorWithMessageMulti(
        function(uint256[] memory) external erroringFunction,
        uint256[] memory params,
        string memory message
    ) internal {
        try erroringFunction(params) { 
            fail();
        } catch Error(string memory error) {
            // Assert revert error matches expected message
            assertEq(error, message);
        }
    }

    /// @notice Calls function and checks for matching revert message (with value)
    /// @param erroringFunction to call
    /// @param param to pass to function
    /// @param value to pass with function call
    /// @param message to check against revert error string
    function assertErrorWithMessagePayable(
        function(uint256) payable external erroringFunction,
        uint256 param,
        uint256 value,
        string memory message
    ) internal {
        try erroringFunction{value: value}(param) { 
            fail();
        } catch Error(string memory error) {
            // Assert revert error matches expected message
            assertEq(error, message);
        }
    }
}