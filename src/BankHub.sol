// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {IDRCoin} from "./IDRCoin.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BankHub is UUPSUpgradeable {
    // constants
    uint32 public constant MIN_INTEREST_RATE = 5;

    // state variables
    address public owner;
    IDRCoin public idrcoin;

    // mappings
    mapping(address => bool) public whiteListed;
    mapping(address => bool) public approved;
    mapping(address => uint32) public interestRate;
    mapping(address => uint256) public depositTimestamp;
    mapping(address => uint256) public savingAmount;

    constructor() {
        // initialize
        _disableInitializers();
    }

    function initialize() public initializer {
        owner = msg.sender;
    }

    // user function
    function deposit(uint256 _amount, address _toBank) public {
        require(whiteListed[_toBank], "bank not whitelisted");
        require(approved[_toBank], "bank not approved");
        require(idrcoin.balanceOf(msg.sender) >= _amount, "insufficient balance");

        // transfer user IDRCoin to bank
        idrcoin.transferFrom(msg.sender, _toBank, _amount);
        
        // update user deposit timestamp and saving amount
        depositTimestamp[msg.sender] = block.timestamp;
        savingAmount[msg.sender] += _amount;
    }

    function withdraw(uint256 _amount, address _fromBank) public {
        require(whiteListed[_fromBank], "bank not whitelisted");
        require(savingAmount[msg.sender] >= _amount, "insufficient balance");

        // calculate interest
        uint256 timePassed = block.timestamp - depositTimestamp[msg.sender];
        uint256 interest = (_amount * timePassed * interestRate[msg.sender]) /
            100;

        // transfer amount + interest to user
        idrcoin.transferFrom(
            address(_fromBank),
            msg.sender,
            _amount + interest
        );
    }

    // bank function 

    // this function is MANDATORY for bank to call before any deposit can be made
    function approve() public {
        require(whiteListed[msg.sender], "bank not whitelisted");
        idrcoin.approve(address(this), idrcoin.balanceOf(msg.sender));
        approved[msg.sender] = true;

        // send IDRCoin to bank as reserve for operation
        idrcoin.transferFrom(owner, msg.sender, 10 ether);
    }

    // admin function
    function changeOwner(address _newOwner) public {
        require(msg.sender == owner, "only owner can change owner");
        owner = _newOwner;
    }

    // whitelist partner bank
    function whiteList(address _bank) public {
        require(msg.sender == owner, "only owner can whitelist");
        whiteListed[_bank] = true;
        interestRate[_bank] = MIN_INTEREST_RATE;
    }

    // revoke whitelist from partner bank
    function revokeWhiteList(address _bank) public {
        require(msg.sender == owner, "only owner can revoke whitelist");
        if (idrcoin.balanceOf(_bank) > 0) {
            idrcoin.transferFrom(_bank, owner, idrcoin.balanceOf(_bank));
        }
    }

    // Implementation of the required UUPSUpgradeable function
    function _authorizeUpgrade(address newImplementation) internal override {
        require(msg.sender == owner, "only owner can authorize upgrades");
    }
}
