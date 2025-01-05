// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUSDT} from "./interfaces/IUSDT.sol";
import {IBankHub} from "./interfaces/IBankHub.sol";

contract IDRCoin is ERC20 {
    // mapping
    mapping(address => uint256) balances;
    mapping(address owner => mapping(address spender => uint256)) allowances;

    // address state
    address admin;
    address taxCollector;
    address public bankHub;
    IUSDT usdt;

    // constant
    // convertion rate from USDT to IDR
    uint256 public constant CONVERSION_RATE = 16000;
    uint8 public constant DECIMALS = 18;

    // enforce ppn 12% for ALL MINTING transaction involving IDRC token
    uint256 public constant TAX = 12;
    uint256 public constant DENOMINATOR = 100;

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert notAdmin();
        }
        _;
    }

    modifier onlyBankHub() {
        if (msg.sender != bankHub) {
            revert notBankHub();
        }
        _;
    }

    // error
    error notAdmin();
    error notBankHub();
    error insufficientBalance();
    error insufficientAllowances();
    error addressZero();
    error BankCannotManualApprove();

    // event
    event IDRC_Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );
    event IDRC_Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event IDRC_Mint(address indexed to, uint256 value);
    event IDRC_Burn(address indexed from, uint256 value);

    // constructor
    constructor(
        address _admin,
        address _taxCollector
    ) ERC20("IDRCoin", "IDRC") {
        admin = _admin;
        taxCollector = _taxCollector;
    }

    // bankHub function
    // this function is called by bankHub to set allowances
    // to allow bankHub spend the IDRC held by _bank
    function setApproval(address _bank, uint256 amount) external onlyBankHub {
        allowances[_bank][msg.sender] = amount;

        emit IDRC_Approval(_bank, msg.sender, amount);
    }

    // this mint function can be called only by bankHub
    // mint new IDRC to _addr, this should be populated by whitelisted bank address
    function mint(address _addr, uint256 amount) external onlyBankHub {
        mint_(_addr, amount);

        emit IDRC_Mint(_addr, amount);
    }

    // external/public function
    // anyone can buy IDRC with USDT with fixed conversion rate
    function convertUSDtoIDR(uint256 amountInUSD) external {
        usdt.transferFrom(msg.sender, address(this), amountInUSD);
        // first we normalize the amount in usd by dividing it with its own decimals
        // then we multiply it with the conversion rate and IDRC decimals
        // result is the amount of IDRC to mint with the correct decimals
        uint256 amountInIDR = (amountInUSD / 10 ** usdt.decimals()) *CONVERSION_RATE *  10 ** decimals();
        mint_(msg.sender, amountInIDR);

        emit IDRC_Mint(msg.sender, amountInIDR);
    }

    // function to approve the _spender to spend _amount of IDRC on behalf of msg.sender
    function approve(
        address _spender,
        uint256 _amount
    ) public override returns (bool) {
        // we dont want the bank to manually approve
        // because it can be exploited by the bank, they can set _amount to 0 and the BankHub
        // cannot spend the loaned IDRC
        if (IBankHub(bankHub).isWhiteListed(msg.sender)) {
            revert BankCannotManualApprove();
        }
        allowances[msg.sender][_spender] = _amount;

        emit IDRC_Approval(msg.sender, _spender, _amount);

        return true;
    }

    // function to transfer the IDRC to _receiver by _amount
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

        emit IDRC_Transfer(msg.sender, _receiver, _amount);

        return true;
    }

    // function to transfer the IDRC from _owner to _receiver by _amount
    // msg.sender must be approved by _owner to spend the _amount of IDRC
    function transferFrom(
        address _owner,
        address _receiver,
        uint256 amount
    ) public override returns (bool) {
        if (allowances[_owner][msg.sender] < amount) {
            revert insufficientAllowances();
        }
        if (_receiver == address(0)) {
            revert addressZero();
        }
        transfer_(_owner, _receiver, amount);

        emit IDRC_Transfer(_owner, _receiver, amount);

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

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    // setter/admin function
    // set the bankHub address
    function setBankHub(address _bankHub) external onlyAdmin {
        bankHub = _bankHub;
    }

    // set the USDT address
    function setUSDT(address _usdt) external onlyAdmin {
        usdt = IUSDT(_usdt);
    }

    // change owner address
    function changeOwner(address admin) external onlyAdmin {
        admin = admin;
    }

    // change taxCollector address
    function changeTaxCollector(address _taxCollector) external onlyAdmin {
        taxCollector = _taxCollector;
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

        emit IDRC_Burn(_account, _amount);
    }
}
