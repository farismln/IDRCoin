// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUSDT} from "./interfaces/IUSDT.sol";

contract IDRCoin is ERC20 {
    // mapping
    mapping(address => uint256) balances;
    mapping(address owner => mapping(address spender => uint256)) allowances;

    // address state
    address admin;
    address taxCollector;
    IUSDT usdt;

    // constant
    // convertion rate from USDT to IDR
    uint256 constant CONVERSION_RATE = 16000;

    // enforce ppn 12% for ALL transaction involving IDRC token
    uint256 constant TAX = 12;
    uint256 constant DENOMINATOR = 100;

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert notAdmin();
        }
        _;
    }

    // error
    error notAdmin();
    error insufficientBalance();
    error insufficientAllowances();
    error addressZero();

    // event

    // constructor
    constructor(
        address _admin,
        address _taxCollector
    ) ERC20("IDRCoin", "IDRC") {
        admin = _admin;
        taxCollector = _taxCollector;
    }

    // external/public function

    function convertUSDtoIDR(uint256 amountInUSD) external {
        usdt.transfer(address(this), amountInUSD);
        uint256 amountInIDR = amountInUSD * CONVERSION_RATE * decimals();
        _mint(msg.sender, amountInIDR);
    }

    function approve(
        address _spender,
        uint256 amount
    ) public override returns (bool) {
        allowances[msg.sender][_spender] = amount;
        return true;
    }

    function transfer(
        address _receiver,
        uint256 _amount
    ) public override returns (bool) {
        if (balanceOf(msg.sender) < _amount) {
            revert insufficientBalance();
        }
        if (_receiver == address(0)) {
            revert addressZero();
        }
        transfer_(msg.sender, _receiver, _amount);
        return true;
    }

    function transferFrom(
        address _owner,
        address _receiver,
        uint256 amount
    ) public override returns (bool) {
        if (allowances[msg.sender][_owner] < amount) {
            revert insufficientAllowances();
        }
        if (_receiver == address(0)) {
            revert addressZero();
        }
        transfer_(_owner, _receiver, amount);
        return true;
    }

    // internal function

    function mint_(address _addr, uint256 amount) internal {
        // calculating the tax amount and then collect it
        uint256 tax = (amount * TAX) / DENOMINATOR;
        balances[_addr] += amount - tax;
        balances[taxCollector] += tax;
    }

    function transfer_(
        address _sender,
        address _receiver,
        uint256 _amount
    ) internal {
        uint256 balanceSenderBefore = balanceOf(_sender);
        uint256 balanceReceiverBefore = balanceOf(_receiver);

        balances[_sender] = balanceSenderBefore - _amount;
        balances[_receiver] = balanceReceiverBefore + _amount;

        // revert if the _amount is zero. we dont want user to waste gas
        require(
            balances[_sender] != balanceSenderBefore ||
                balances[_receiver] != balanceReceiverBefore,
            "cant transfer 0 amount"
        );
    }

    // view function

    function balanceOf(
        address _addr
    ) public view override returns (uint256 amount) {
        return balances[_addr];
    }

    // setter/admin function

    function setUSDT(address _usdt) external onlyAdmin {
        usdt = IUSDT(_usdt);
    }

    function changeOwner(address admin) external onlyAdmin {
        admin = admin;
    }

    // collect USDT for public goods purpose

    function withdrawUSDT(address _addr) external onlyAdmin {
        // transfer usdt to admin specified address
        uint256 amount = usdt.balanceOf(address(this));
        usdt.transfer(_addr, amount);
    }

    // burn ALL corruptor IDRC with this function
    function burn(address _account, uint256 _amount) public onlyAdmin {
        transfer_(_account, address(0), _amount);
    }
}
