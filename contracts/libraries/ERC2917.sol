//SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "./SafeMath.sol";

/*
    The Objective of ERC2917 Demo is to implement a decentralized staking mechanism, which calculates users' share
    by accumulating productiviy * time. And calculates users revenue from anytime t0 to t1 by the formula below:

        user_accumulated_productivity(time1) - user_accumulated_productivity(time0)
       _____________________________________________________________________________  * (gross_product(t1) - gross_product(t0))
       total_accumulated_productivity(time1) - total_accumulated_productivity(time0)

*/
contract ERC2917 {
    using SafeMath for uint256;

    uint256 public mintCumulation;
    uint256 public amountPerBlock;
    uint256 public nounce;

    function incNounce() public {
        nounce++;
    }

    // implementation of ERC20 interfaces.
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    uint256 public maxSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event InterestRatePerBlockChanged(uint256 oldValue, uint256 newValue);
    event ProductivityIncreased(address indexed user, uint256 value);
    event ProductivityDecreased(address indexed user, uint256 value);

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        require(balanceOf[from] >= value, "ERC20Token: INSUFFICIENT_BALANCE");
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        if (to == address(0)) {
            // burn
            totalSupply = totalSupply.sub(value);
        }
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value)
        external
        virtual
        returns (bool)
    {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value)
        external
        virtual
        returns (bool)
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external virtual returns (bool) {
        require(
            allowance[from][msg.sender] >= value,
            "ERC20Token: INSUFFICIENT_ALLOWANCE"
        );
        allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        _transfer(from, to, value);
        return true;
    }

    // end of implementation of ERC20
    uint256 lastRewardBlock;
    uint256 totalProductivity;
    uint256 accAmountPerShare;
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
        uint256 rewardEarn; // Reward earn and not minted
    }

    mapping(address => UserInfo) public users;

    // creation of the interests token.
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _interestsRate,
        uint256 _maxSupply
    ) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        amountPerBlock = _interestsRate;
        maxSupply = _maxSupply;
    }

    // External function call
    // This function adjust how many token will be produced by each block, eg:
    // changeAmountPerBlock(100)
    // will set the produce rate to 100/block.
    function _changeInterestRatePerBlock(uint256 value)
        internal
        virtual
        returns (bool)
    {
        uint256 old = amountPerBlock;
        require(value != old, "AMOUNT_PER_BLOCK_NO_CHANGE");

        _update();
        amountPerBlock = value;

        emit InterestRatePerBlockChanged(old, value);
        return true;
    }

    // Update reward variables of the given pool to be up-to-date.
    function _update() internal virtual {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalProductivity == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 reward = _currentReward();
        balanceOf[address(this)] = balanceOf[address(this)].add(reward);

        // check totalSupply reached maxSupply
        if(totalSupply.add(reward) >= maxSupply) {
            reward = maxSupply - totalSupply;
            // disable mint SIGN token
            amountPerBlock = 0;
        }

        totalSupply = totalSupply.add(reward);

        accAmountPerShare = accAmountPerShare.add(
            reward.mul(1e12).div(totalProductivity)
        );
        lastRewardBlock = block.number;
    }

    function _currentReward() internal view virtual returns (uint256) {
        uint256 multiplier = block.number.sub(lastRewardBlock);
        return multiplier.mul(amountPerBlock);
    }

    // Audit user's reward to be up-to-date
    function _audit(address user) internal virtual {
        UserInfo storage userInfo = users[user];
        if (userInfo.amount > 0) {
            uint256 pending = userInfo
            .amount
            .mul(accAmountPerShare)
            .div(1e12)
            .sub(userInfo.rewardDebt);
            userInfo.rewardEarn = userInfo.rewardEarn.add(pending);
            mintCumulation = mintCumulation.add(pending);
            userInfo.rewardDebt = userInfo.amount.mul(accAmountPerShare).div(
                1e12
            );
        }
    }

    // External function call
    // This function increase user's productivity and updates the global productivity.
    // the users' actual share percentage will calculated by:
    // Formula:     user_productivity / global_productivity
    function _increaseProductivity(address user, uint256 value)
        internal
        virtual
        returns (bool)
    {
        require(value > 0, "PRODUCTIVITY_VALUE_MUST_BE_GREATER_THAN_ZERO");

        UserInfo storage userInfo = users[user];
        _update();
        _audit(user);

        totalProductivity = totalProductivity.add(value);

        userInfo.amount = userInfo.amount.add(value);
        userInfo.rewardDebt = userInfo.amount.mul(accAmountPerShare).div(1e12);
        emit ProductivityIncreased(user, value);
        return true;
    }

    // External function call
    // This function will decreases user's productivity by value, and updates the global productivity
    // it will record which block this is happenning and accumulates the area of (productivity * time)
    function _decreaseProductivity(address user, uint256 value)
        internal
        virtual
        returns (bool)
    {
        UserInfo storage userInfo = users[user];
        require(
            value > 0 && userInfo.amount >= value,
            "INSUFFICIENT_PRODUCTIVITY"
        );
        _update();
        _audit(user);

        userInfo.amount = userInfo.amount.sub(value);
        userInfo.rewardDebt = userInfo.amount.mul(accAmountPerShare).div(1e12);
        totalProductivity = totalProductivity.sub(value);

        emit ProductivityDecreased(user, value);
        return true;
    }

    function takeWithAddress(address user) public view returns (uint256) {
        UserInfo storage userInfo = users[user];
        uint256 _accAmountPerShare = accAmountPerShare;
        // uint256 lpSupply = totalProductivity;
        if (block.number > lastRewardBlock && totalProductivity != 0) {
            uint256 reward = _currentReward();
            _accAmountPerShare = _accAmountPerShare.add(
                reward.mul(1e12).div(totalProductivity)
            );
        }
        return
            userInfo
                .amount
                .mul(_accAmountPerShare)
                .div(1e12)
                .sub(userInfo.rewardDebt)
                .add(userInfo.rewardEarn);
    }

    function take() external view virtual returns (uint256) {
        return takeWithAddress(msg.sender);
    }

    // Returns how much a user could earn plus the giving block number.
    function takeWithBlock() external view virtual returns (uint256, uint256) {
        uint256 earn = takeWithAddress(msg.sender);
        return (earn, block.number);
    }

    // External function call
    // When user calls this function, it will calculate how many token will mint to user from his productivity * time
    // Also it calculates global token supply from last time the user mint to this time.
    function _mint() internal virtual returns (uint256) {
        _update();
        _audit(msg.sender);
        require(users[msg.sender].rewardEarn > 0, "NO_PRODUCTIVITY");
        uint256 amount = users[msg.sender].rewardEarn;
        _transfer(address(this), msg.sender, users[msg.sender].rewardEarn);
        users[msg.sender].rewardEarn = 0;
        return amount;
    }

    // Returns how many productivity a user has and global has.
    function getProductivity(address user)
        external
        view
        virtual
        returns (uint256, uint256)
    {
        return (users[user].amount, totalProductivity);
    }

    // Returns the current gorss product rate.
    function interestsPerBlock() external view virtual returns (uint256) {
        return accAmountPerShare;
    }
}
