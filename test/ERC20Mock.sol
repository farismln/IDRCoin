// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {IUSDT} from "../src/interfaces/IUSDT.sol";

contract USDTMock is IUSDT {
    string internal _name;
    string internal _symbol;
    uint256 internal _decimals;

    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balanceOf;
    mapping(address => mapping(address => uint256)) internal _allowance;

    constructor() {
        _name = "Mock USD";
        _symbol = "USDT Mock";
        _decimals = 6;
    }

    function decimals() external view returns (uint256) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external {
        _totalSupply += amount;
        _balanceOf[account] += amount;
    }

    function transfer(address recipient, uint256 amount) external {
        require(_balanceOf[msg.sender] >= amount, "USDTMock: insufficient balance");
        require(recipient != msg.sender, "USDTMock: cannot transfer to self");
        _balanceOf[msg.sender] -= amount;
        _balanceOf[recipient] += amount;
    }

    function approve(address spender, uint256 amount) external {
        _allowance[msg.sender][spender] = amount;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external {
        require(_balanceOf[sender] >= amount, "USDTMock: insufficient balance");
        require(_allowance[sender][msg.sender] >= amount, "USDTMock: insufficient allowance");
        require(recipient != sender, "USDTMock: cannot transfer to self");
        _balanceOf[sender] -= amount;
        _balanceOf[recipient] += amount;
        _allowance[sender][msg.sender] -= amount;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balanceOf[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

}
