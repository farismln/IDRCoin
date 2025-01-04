// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {IDRCoin} from "./IDRCoin.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BankHub is UUPSUpgradeable {
    // constants
    uint32 public constant MIN_INTEREST_RATE = 5;
    uint32 public constant DENOMINATOR = 100;
    uint256 public constant MIN_LOAN_AMOUNT = 10e18;

    // state variables
    address public owner;
    IDRCoin public idrcoin;

    // mappings
    mapping(address => bool) public whiteListed;
    mapping(address => uint32) public interestRate;
    mapping(address => uint256) public depositTimestamp;
    mapping(address => uint256) public savingAmount;

    // modifier
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert notOwner();
        }
        _;
    }

    modifier onlyWhiteListed() {
        if (!whiteListed[msg.sender]) {
            revert notWhiteListed();
        }
        _;
    }

    // error
    error notOwner();
    error notWhiteListed();
    error insufficientLoanAmount();
    error invalidInterestRate();

    // event
    event Deposit(address indexed user, address indexed bank, uint256 amount);
    event Withdraw(address indexed user, address indexed bank, uint256 amount);
    event Approved(address indexed bank);

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        owner = msg.sender;
    }

    // user function
    // depositing IDRCoin to whitelisted bank, user would then have saving account with interest
    function depositToBank(uint256 _amount, address _toBank) public {
        if (!whiteListed[_toBank]) {
            revert notWhiteListed();
        }
        require(
            idrcoin.balanceOf(msg.sender) >= _amount,
            "insufficient balance"
        );

        // transfer user IDRCoin to bank
        idrcoin.transferFrom(msg.sender, _toBank, _amount);

        // update user deposit timestamp and saving amount
        depositTimestamp[msg.sender] = block.timestamp;
        savingAmount[msg.sender] += _amount;
        emit Deposit(msg.sender, _toBank, _amount);
    }

    // withdraw IDRCoin from saving account
    // user's interest would be applied here
    function withdraw(uint256 _amount, address _fromBank) public {
        require(whiteListed[_fromBank], "bank not whitelisted");
        require(savingAmount[msg.sender] >= _amount, "insufficient balance");

        // calculate interest
        uint256 timePassed = block.timestamp - depositTimestamp[msg.sender];
        uint256 interest = (_amount * timePassed * interestRate[msg.sender]) /
            DENOMINATOR /
            365 days;

        // update user savingAmount
        // interest is not deducted from user savingAmount because it would underflow
        savingAmount[msg.sender] -= _amount;

        // instead, it would be minted to user
        idrcoin.mint(msg.sender, interest);

        // transfer amount
        idrcoin.transferFrom(address(_fromBank), msg.sender, _amount);

        emit Withdraw(msg.sender, _fromBank, _amount);
    }

    // bank function
    // get IDRCoin for bank reserve
    function getIDRCoinLoan(
        address _bank,
        uint256 _amount
    ) public onlyWhiteListed {
        require(msg.sender == _bank, "only bank can receive loan from BankHub");
        if (_amount < MIN_LOAN_AMOUNT) {
            revert insufficientLoanAmount();
        }

        idrcoin.mint(_bank, _amount);
    }

    // set interest rate for saving account
    // this function would retroactively apply the new interest rate to all user savingAmount
    function setInterestRate(uint32 _interestRate) public onlyWhiteListed {
        interestRate[msg.sender] = _interestRate;
    }

    // admin function
    // change owner
    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    // whitelist partner bank, set interest rate and approve unlimited IDRCoin transfer by this contract
    function whiteList(address _bank) public onlyOwner {
        whiteListed[_bank] = true;
        interestRate[_bank] = MIN_INTEREST_RATE;

        idrcoin.setApproval(_bank, type(uint256).max);
        emit Approved(_bank);
    }

    // revoke whitelist from partner bank
    // collect all IDRCoin from bank
    function revokeWhiteList(address _bank) public onlyOwner {
        if (idrcoin.balanceOf(_bank) > 0) {
            idrcoin.transferFrom(_bank, owner, idrcoin.balanceOf(_bank));
        }
    }

    // Implementation of the required UUPSUpgradeable function
    function _authorizeUpgrade(address newImplementation) internal override {
        require(msg.sender == owner, "only owner can authorize upgrades");
    }

    // view function
    function isWhiteListed(address _bank) public view returns (bool) {
        return whiteListed[_bank];
    }

    function checkSavingAmountIncludingInterest(
        address _user
    ) public view returns (uint256) {
        uint256 timePassed = block.timestamp - depositTimestamp[_user];
        uint256 interest = (savingAmount[_user] *
            timePassed *
            interestRate[_user]) /
            DENOMINATOR /
            365 days;
        uint256 taxPercent = idrcoin.TAX();
        uint256 taxDenominator = idrcoin.DENOMINATOR();
        uint256 tax = (interest * taxPercent) / taxDenominator;
        interest -= tax;
        return savingAmount[_user] + interest;
    }
}
