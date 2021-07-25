pragma solidity >=0.6.12;
// SPDX-License-Identifier: UNLICENSED

/*
 ____  _           _____     _                _       
/ ___|(_) __ _ _ _|_   _|__ | | _____ _ __   (_) ___  
\___ \| |/ _` | '_ \| |/ _ \| |/ / _ \ '_ \  | |/ _ \ 
 ___) | | (_| | | | | | (_) |   <  __/ | | |_| | (_) |
|____/|_|\__, |_| |_|_|\___/|_|\_\___|_| |_(_)_|\___/ 
         |___/

* There will be 1 SIGN minted every 1 block. When 10,072,021 SIGN is reached, no more can be minted
* You will get 1 Productivity Point when you sign a name on blockchain. The more Productivity Points you have, the more SIGN you can claim
* 0.01 BNB is the fee to pay per sign. When the total fee reaches 1 BNB will use it to buy SIGN on pancakeswap. Amount SIGN bought can't be transferred to another wallet
* Amount SIGN you can claim will be calculated according to the standard formula EIP-2917: 

    The Objective of ERC2917 is to implement a decentralized staking mechanism, which calculates users' share
    by accumulating productiviy * time. And calculates users revenue from anytime t0 to t1 by the formula below:

    user_accumulated_productivity(time1) - user_accumulated_productivity(time0)
    _____________________________________________________________________________  * (gross_product(t1) - gross_product(t0))
    total_accumulated_productivity(time1) - total_accumulated_productivity(time0)
*/

import "./libraries/ERC2917.sol";
import "./libraries/SafeMath.sol";
import "./libraries/PancakeLibrary.sol";
import "./interfaces/IPancakeRouter.sol";

contract SignToken is ERC2917("Sign Token", "SIGN", 18, 1 * 10**18, 10072021 * 10**18) { // amountPerBlock = 1 SIGN, maxSupply = 10072021 SIGN
    using SafeMath for uint;

    uint constant public FEE = 0.01 * 10**18;               // 0.01 BNB is the fee to pay per sign
    uint constant public MAX_FEE = 1 * 10**18;              // When the total fee reaches 1 BNB will use it to buy SIGN
    uint constant private MIN_STRING_LENGTH = 5;
    uint constant private MAX_STRING_LENGTH = 255;
    uint public nextSignId = 0;

    mapping(uint => string) private names;                  // signId => name;

    event Sign(address indexed user, uint indexed signId, string name);
    event Claim(address indexed user, uint amount);

    IPancakeRouter public immutable pancakeV2Router;

    constructor() public {
        pancakeV2Router = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    function sign (string memory name) external payable returns (bool) {
        uint nameLength = bytes(name).length;
        require(nameLength >= MIN_STRING_LENGTH && nameLength <= MAX_STRING_LENGTH, "MIN_NAME_5 & MAX_NAME_255");
        require(msg.value >= FEE, "NOT_ENOUGH_FEE");

        _checkSwap();

        uint signId = nextSignId;
        names[signId] = name;
        _increaseProductivity(msg.sender, 1);

        nextSignId = nextSignId.add(1);

        emit Sign(msg.sender, signId, name);

        return true;
    }

    function claim () external returns (bool) {
        uint amount = _mint();
        emit Claim(msg.sender, amount);
        return true;
    }

    function getNameBySignId (uint signId) public view returns (string memory) {
        return names[signId];
    }

    function _checkSwap() internal {
        uint currentBalance = address(this).balance;

        if(currentBalance >= MAX_FEE) {
            _swapETHForToken(currentBalance);
        }
    }

    function _swapETHForToken(uint256 amountETH) private {
        address WETH = pancakeV2Router.WETH();
        address factory = pancakeV2Router.factory();
        address pair = PancakeLibrary.pairFor(factory, address(this), WETH);
        if(pair == address(0)) return;

        (uint reserveIn, uint reserveOut) = PancakeLibrary.getReserves(factory, WETH, address(this));
        uint amountOut = PancakeLibrary.getAmountOut(amountETH, reserveIn, reserveOut);

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(this);

        // buy token and transfer all to burn address
        pancakeV2Router.swapETHForExactTokens
        {value: amountETH}
        (
            amountOut,
            path,
            address(0), // burn address
            block.timestamp
        );
    }
}
