// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {IDRCoin} from "../src/IDRCoin.sol";
import {BankHub} from "../src/BankHub.sol";
import {USDTMock} from "./ERC20Mock.sol";

contract Base is Test {
    IDRCoin public idrCoin;
    BankHub public bankHub;
    USDTMock public usdtMock;

    address admin = makeAddr("admin");
    address taxCollector = makeAddr("taxCollector");
    address bankABC = makeAddr("bankABC");
    address bankIRB = makeAddr("bankIRB");

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(admin);
        // deploy the contract
        idrCoin = new IDRCoin(admin, taxCollector);
        bankHub = new BankHub(admin);
        usdtMock = new USDTMock();

        // set the bankHub address in idrCoin
        idrCoin.setBankHub(address(bankHub));

        // set usdtMock address in idrCoin
        idrCoin.setUSDT(address(usdtMock));

        // set the idrCoin address in bankHub
        bankHub.setIDRCoin(address(idrCoin));

        // set bank ABC and bank IRB as whiteListed
        bankHub.whiteList(bankABC);
        bankHub.whiteList(bankIRB);

        // mint some USDT to alice and bob
        usdtMock.mint(alice, 1000e6);
        usdtMock.mint(bob, 1000e6);

        vm.stopPrank();
    }

    // helper function for converting USDT to IDRCoin
    function convertUSDTtoIDR(address user, uint256 amountInUSDT) public {
        vm.startPrank(user);
        if (usdtMock.balanceOf(user) < amountInUSDT) {
            usdtMock.mint(user, amountInUSDT);
        }
        usdtMock.approve(address(idrCoin), amountInUSDT);
        idrCoin.convertUSDtoIDR(amountInUSDT);
        console.log("user balance: ", idrCoin.balanceOf(user));

        // check the balance is reduced by tax
        uint256 conversionRate = idrCoin.CONVERSION_RATE();
        uint256 tax = idrCoin.TAX();
        uint256 denominator = idrCoin.DENOMINATOR();
        uint256 idrCoinDecimals = idrCoin.decimals();
        uint256 usdtDecimals = usdtMock.decimals();
        uint256 idrAmount = ((amountInUSDT * conversionRate) /
            10 ** usdtDecimals) * 10 ** idrCoinDecimals;
        uint256 taxAmount = (idrAmount * tax) / denominator;
        uint256 balance = idrCoin.balanceOf(user);
        assertEq(balance, idrAmount - taxAmount);

        vm.stopPrank();
    }

    // helper function for depositing IDRCoin to bank
    function depositToBank(address user, uint256 usdtAmount, address bank) public returns (uint256 amount) {
        convertUSDTtoIDR(user, usdtAmount);
        vm.startPrank(user);
        amount = idrCoin.balanceOf(user);

        // approve bankHub to spend the IDRCoin
        idrCoin.approve(address(bankHub), amount);

        // deposit the IDRCoin to bankABC
        bankHub.depositToBank(amount, bank);
        vm.stopPrank();
    }

    // test function for IDRCoin

    function test_convertUSDtoIDR() public {
        // convert 100 dollar worth of usdt
        convertUSDTtoIDR(alice, 100e6);
    }

    function test_transferIDRCoin() public {
        convertUSDTtoIDR(alice, 100e6);
        vm.startPrank(alice);
        uint256 amount = idrCoin.balanceOf(alice);

        // send the IDRCoin to bob
        idrCoin.transfer(bob, amount);

        // assert
        assertEq(idrCoin.balanceOf(alice), 0);
        assertEq(idrCoin.balanceOf(bob), amount);
        vm.stopPrank();
    }

    function test_transferFromIDRCoin() public {
        // create charlie address
        address charlie = makeAddr("charlie");

        // alice convert 100 dollar worth of usdt
        convertUSDTtoIDR(alice, 100e6);
        vm.startPrank(alice);
        uint256 amount = idrCoin.balanceOf(alice);

        // alice approve bob to transfer her IDRCoin
        idrCoin.approve(bob, amount);
        vm.stopPrank();

        // bob transfer the IDRCoin from alice to charlie
        vm.startPrank(bob);
        idrCoin.transferFrom(alice, charlie, amount);
        vm.stopPrank();

        // assert
        assertEq(idrCoin.balanceOf(alice), 0);
        assertEq(idrCoin.balanceOf(bob), 0);
        assertEq(idrCoin.balanceOf(charlie), amount);
    }

    function test_ownerWithdrawUSDT() public {
        uint256 amount = 100e6;
        convertUSDTtoIDR(alice, amount);

        vm.startPrank(admin);
        uint256 usdtAmountBefore = usdtMock.balanceOf(admin);
        idrCoin.withdrawUSDT(admin);
        uint256 usdtAmountAfter = usdtMock.balanceOf(admin);

        // assert
        assertEq(amount, usdtAmountAfter - usdtAmountBefore);
    }

    function test_ownerBurnIDRCoin() public {
        uint256 amount = 100e6;
        convertUSDTtoIDR(alice, amount);

        vm.startPrank(admin);
        idrCoin.burn(alice, idrCoin.balanceOf(alice));

        // assert
        assertEq(idrCoin.balanceOf(alice), 0);
    }

    // test function for BankHub
    function test_changeOwner() public {
        vm.startPrank(admin);
        bankHub.changeOwner(bob);

        // assert
        assertEq(bankHub.owner(), bob);
    }

    function test_whitelistNewBank() public {
        vm.startPrank(admin);

        address newBank = makeAddr("newBank");
        bankHub.whiteList(newBank);

        // assert
        assertTrue(bankHub.isWhiteListed(newBank));
        assertEq(bankHub.interestRate(newBank), bankHub.MIN_INTEREST_RATE());
        assertEq(idrCoin.allowance(newBank, address(bankHub)), type(uint256).max);
    }

    function test_depositToBank() public {
        uint256 amount = depositToBank(alice, 100e6, bankABC);
        // assert
        assertEq(idrCoin.balanceOf(alice), 0);
        assertEq(idrCoin.balanceOf(bankABC), amount);
        vm.stopPrank();
    }

    function test_withdrawFromBank_0Duration() public {
        uint256 durationInSeconds = 0;

        vm.warp(1000);
        uint256 amount = depositToBank(alice, 100e6, bankABC);

        vm.warp(1000 + durationInSeconds);
        uint256 amountInViewerFunction = bankHub.checkSavingAmountIncludingInterest(alice, bankABC);
        vm.prank(alice);
        bankHub.withdraw(amount, bankABC);
        uint256 interest = (amount * durationInSeconds * bankHub.interestRate(bankABC)) / bankHub.DENOMINATOR() / 365 days;
        // console.log("interest: ", interest);
        uint256 interestWithTax = interest - (interest * idrCoin.TAX() / idrCoin.DENOMINATOR());
        // console.log("interestWithTax: ", interestWithTax);
        uint256 amountWithReturn = amount + interestWithTax;

        // assert
        assertEq(idrCoin.balanceOf(alice), amountWithReturn);
        assertEq(amountInViewerFunction, amountWithReturn);
    }
    function test_withdrawFromBank_30Days() public {
        uint256 durationInSeconds = 30 days;

        vm.warp(1000);
        uint256 amount = depositToBank(alice, 100e6, bankABC);

        vm.warp(1000 + durationInSeconds);
        uint256 amountInViewerFunction = bankHub.checkSavingAmountIncludingInterest(alice, bankABC);
        vm.prank(alice);
        bankHub.withdraw(amount, bankABC);
        uint256 interest = (amount * durationInSeconds * bankHub.interestRate(bankABC)) / bankHub.DENOMINATOR() / 365 days;
        // console.log("interest: ", interest);
        uint256 interestWithTax = interest - (interest * idrCoin.TAX() / idrCoin.DENOMINATOR());
        // console.log("interestWithTax: ", interestWithTax);
        uint256 amountWithReturn = amount + interestWithTax;

        // assert
        assertEq(idrCoin.balanceOf(alice), amountWithReturn);
        assertEq(amountInViewerFunction, amountWithReturn);
    }

    function test_bankGetLoan() public {
        vm.startPrank(bankABC);

        uint256 amount = 100e18;
        bankHub.getIDRCoinLoan(bankABC, amount);
        uint256 amountWithTax = amount - (amount * idrCoin.TAX() / idrCoin.DENOMINATOR());

        vm.stopPrank();

        // assert
        assertEq(idrCoin.balanceOf(bankABC), amountWithTax);
    }

    function test_revokeWhitelist() public {
        vm.startPrank(bankABC);
        uint256 amount = 100e18;
        bankHub.getIDRCoinLoan(bankABC, amount);
        uint256 amountWithTax = amount - (amount * idrCoin.TAX() / idrCoin.DENOMINATOR());
        assertEq(idrCoin.balanceOf(bankABC), amountWithTax);
        vm.stopPrank();

        vm.startPrank(admin);
        bankHub.revokeWhiteList(bankABC);

        // assert
        assertEq(idrCoin.balanceOf(bankABC), 0);
    }

    function test_setInterestRate() public {
        vm.startPrank(bankABC);
        bankHub.setInterestRate(15);

        // assert
        assertEq(bankHub.interestRate(bankABC), 15);
    } 
}
