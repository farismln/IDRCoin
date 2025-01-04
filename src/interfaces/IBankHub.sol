// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

interface IBankHub {
    function isWhiteListed(address _address) external view returns (bool);
}
