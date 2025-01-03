// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUSDT {
    function decimals() external returns (uint);

    function balanceOf(address who) external returns (uint);

    function transfer(address to, uint value) external;

    function approve(address spender, uint value) external;
}
