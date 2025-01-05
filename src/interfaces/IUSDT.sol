// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUSDT {
    function decimals() external returns (uint256);

    function balanceOf(address who) external returns (uint256);

    function transfer(address to, uint256 value) external;

    function transferFrom(address from, address to, uint256 value) external;

    function approve(address spender, uint256 value) external;
}
