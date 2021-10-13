// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

abstract contract Hevm {
    /// @notice Sets the block timestamp to x
    function warp(uint x) public virtual;
}