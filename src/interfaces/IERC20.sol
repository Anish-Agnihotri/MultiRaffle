// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface IERC20 {
  /// @notice ERC20 check balance of user
  function balanceOf(address user) external returns (uint256);
}