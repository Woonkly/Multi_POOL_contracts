// SPDX-License-Identifier: MIT

/**
MIT License

Copyright (c) 2021 Woonkly OU

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED BY WOONKLY OU "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

pragma solidity ^0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/GSN/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/token/ERC20/ERC20.sol";
import "https://github.com/Woonkly/MartinHSolUtils/releasev34/OwnersLMH.sol";

contract MPLiquidityManager is OwnersLMH, ERC20 {
    using SafeMath for uint256;

    //Section Type declarations

    struct Collected {
        uint256 amount;
        uint256 block;
        uint256 ts;
    }

    struct Stake {
        address account;
        bool autoCompound;
        Collected tokena;
        Collected tokenb;
        uint256 genesisblock;
        uint8 flag; //0 no exist  1 exist 2 deleted
    }

    struct Rewards {
        Collected tokena;
        Collected tokenb;
    }

    struct Genesis {
        uint256 blkNumber;
        uint256 birth;
    }

    //Section State variables
    uint256 internal _lastIndexStakes;
    mapping(uint256 => Stake) internal _Stakes;
    mapping(address => uint256) internal _IDStakesIndex;
    uint256 internal _StakeCount;

    Genesis public genesis;

    Rewards rewAmount;

    //Section Modifier
    modifier onlyNewStake(address account) {
        require(!this.StakeExist(account), "1");
        _;
    }

    modifier onlyStakeExist(address account) {
        require(StakeExist(account), "1");
        _;
    }

    modifier onlyStakeIndexExist(uint256 index) {
        require(StakeIndexExist(index), "1");
        _;
    }

    //Section Events

    event AllStakeRemoved();
    event TrackingEvent(
        address indexed account,
        string _event,
        uint256 sub,
        uint256 add,
        uint256 balance,
        uint256 blkNumber,
        uint256 time
    );
    event NewReward(
        uint256 oldAmount,
        uint256 added,
        uint256 newAmount,
        bool isTkA,
        uint256 liquidity,
        uint256 blkNumber,
        uint256 time
    );

    //Section functions

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name, string memory symbol)
        public
        ERC20(name, symbol)
    {
        _lastIndexStakes = 0;
        _StakeCount = 0;
        genesis.blkNumber = block.number;
        genesis.birth = block.timestamp;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * This intentionally made to block transfers this token (nontransferable)
     */

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(false);
        super._transfer(sender, recipient, amount);
    }

    /**
     * @dev Manages new liquidity providers (stackers) if it exists updates liquidity balance
     *
     * Requirements:
     *
     * - only Is InOwners require
     */
    function manageStake(address account, uint256 amount)
        public
        onlyIsInOwners
        returns (bool)
    {
        if (!StakeExist(account)) {
            newStake(account, amount, 0, 0, false);
        } else {
            addToStake(account, amount);
        }

        return true;
    }

    /**
     * @dev Transfer liquidity from account to other
     * If destination acc not exist is created or add destination liquidity
     * origin is removed
     * Requirements:
     *
     * - only Is InOwners require
     */

    function transferStake(address origin, address destination)
        external
        onlyIsInOwners
        returns (bool)
    {
        require(StakeExist(origin), "1");

        (, uint256 amount, , , , ) = getStake(origin);

        manageStake(destination, amount);

        removeStake(origin);

        return true;
    }

    /**
     * @dev Get stakers qty
     *
     */

    function getStakeCount() public view returns (uint256) {
        return _StakeCount;
    }

    /**
     * @dev Get last index used to stored liquidy providers
     *
     */

    function getLastIndexStakes() public view returns (uint256) {
        return _lastIndexStakes;
    }

    /**
     * @dev Get if liquidy providers exist
     *
     */

    function StakeExist(address account) public view returns (bool) {
        return _StakeExist(_IDStakesIndex[account]);
    }

    /**
     * @dev Get if liquidy providers index exist
     *
     */
    function StakeIndexExist(uint256 index) public view returns (bool) {
        return (index < (_lastIndexStakes + 1));
    }

    /**
     * @dev Get if liquidy providers exist
     *
     */
    function _StakeExist(uint256 StakeID) internal view returns (bool) {
        return (_Stakes[StakeID].flag == 1);
    }

    /**
     * @dev Add new liquidity provider data
     *
     * Emits {TrackingEvent} ev.
     *
     * Return las index used
     */
    function _newStake(
        address account,
        uint256 amount,
        uint256 tka,
        uint256 tkb,
        bool autoc
    ) internal returns (uint256) {
        _lastIndexStakes = _lastIndexStakes.add(1);
        _StakeCount = _StakeCount.add(1);

        _Stakes[_lastIndexStakes].account = account;
        _Stakes[_lastIndexStakes].autoCompound = autoc;
        _Stakes[_lastIndexStakes].flag = 1;

        _Stakes[_lastIndexStakes].genesisblock = block.number;

        _Stakes[_lastIndexStakes].tokena.amount = tka;
        _Stakes[_lastIndexStakes].tokena.block = 0;
        _Stakes[_lastIndexStakes].tokena.ts = 0;

        _Stakes[_lastIndexStakes].tokenb.amount = tkb;
        _Stakes[_lastIndexStakes].tokenb.block = 0;
        _Stakes[_lastIndexStakes].tokenb.ts = 0;

        _IDStakesIndex[account] = _lastIndexStakes;

        if (amount > 0) {
            _mint(account, amount);
        }

        emit TrackingEvent(
            account,
            "addNewStake",
            0,
            amount,
            amount,
            block.number,
            now
        );

        return _lastIndexStakes;
    }

    /**
     * @dev Add new liquidity provider data
     *
     *
     * Return las index used
     *
     * Requirements:
     *  only Is InOwners  && stake no exist
     */
    function newStake(
        address account,
        uint256 amount,
        uint256 tka,
        uint256 tkb,
        bool autoc
    ) public onlyIsInOwners onlyNewStake(account) returns (uint256) {
        return _newStake(account, amount, tka, tkb, autoc);
    }

    /**
     * @dev Add new liquidity provider data
     *
     *
     * Requirements:
     *  only Is InOwners  && stake exist
     *
     * Return las index used
     */
    function addToStake(address account, uint256 addAmount)
        public
        onlyIsInOwners
        onlyStakeExist(account)
        returns (uint256)
    {
        if (addAmount > 0) {
            _mint(account, addAmount);
        }

        emit TrackingEvent(
            account,
            "StakeAdded",
            0,
            addAmount,
            balanceOf(account),
            block.number,
            now
        );
        return _IDStakesIndex[account];
    }

    /**
     * @dev Get totals rewards amounts
     *
     * isTKA = Coin parts
     */
    function getTotalReward(bool isTKA)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        if (isTKA == true) {
            return (
                rewAmount.tokena.amount,
                rewAmount.tokena.block,
                rewAmount.tokena.ts
            );
        } else {
            return (
                rewAmount.tokenb.amount,
                rewAmount.tokenb.block,
                rewAmount.tokenb.ts
            );
        }
    }

    /**
     * @dev Add new reward amount
     *
     * isTKA = Coin parts
     *
     * Emit {NewReward} evt
     *
     * Requirements:
     *  only Is InOwners
     */
    function addReward(uint256 amount, bool isTKA)
        external
        onlyIsInOwners
        returns (bool)
    {
        uint256 old = 0;
        uint256 newr = 0;

        if (isTKA) {
            old = rewAmount.tokena.amount;
            rewAmount.tokena.amount = rewAmount.tokena.amount.add(amount);
            rewAmount.tokena.block = block.number;
            rewAmount.tokena.ts = now;
            newr = rewAmount.tokena.amount;
        } else {
            old = rewAmount.tokenb.amount;
            rewAmount.tokenb.amount = rewAmount.tokenb.amount.add(amount);
            rewAmount.tokenb.block = block.number;
            rewAmount.tokenb.ts = now;
            newr = rewAmount.tokenb.amount;
        }

        emit NewReward(
            old,
            amount,
            newr,
            isTKA,
            totalSupply(),
            block.number,
            now
        );
        return true;
    }

    /**
     * @dev Substract a reward amount
     *
     * isTKA = Coin parts
     *
     * Emit {NewReward} evt
     *
     * Requirements:
     *  only Is InOwners
     */
    function subReward(uint256 amount, bool isTKA)
        external
        onlyIsInOwners
        returns (bool)
    {
        uint256 old = 0;
        uint256 newr = 0;

        if (isTKA) {
            old = rewAmount.tokena.amount;

            if (rewAmount.tokena.amount > amount) {
                rewAmount.tokena.amount = rewAmount.tokena.amount.sub(amount);
            } else {
                rewAmount.tokena.amount = 0;
            }

            rewAmount.tokena.block = block.number;
            rewAmount.tokena.ts = now;
            newr = rewAmount.tokena.amount;
        } else {
            old = rewAmount.tokenb.amount;

            if (rewAmount.tokenb.amount > amount) {
                rewAmount.tokenb.amount = rewAmount.tokenb.amount.sub(amount);
            } else {
                rewAmount.tokenb.amount = 0;
            }

            rewAmount.tokenb.block = block.number;
            rewAmount.tokenb.ts = now;
            newr = rewAmount.tokenb.amount;
        }

        emit NewReward(
            old,
            amount,
            newr,
            isTKA,
            totalSupply(),
            block.number,
            now
        );
        return true;
    }

    /**
     * @dev Set  reward amount
     *
     *
     * Emit {TrackingEvent} evt
     *
     * Requirements:
     *  only Is InOwners && stake must exist
     */
    function renewStake(address account, uint256 newAmount)
        external
        onlyIsInOwners
        onlyStakeExist(account)
        returns (uint256)
    {
        uint256 oldAmount = balanceOf(account);
        if (oldAmount > 0) {
            _burn(account, oldAmount);
        }

        if (newAmount > 0) {
            _mint(account, newAmount);
        }

        emit TrackingEvent(
            account,
            "StakeReNewed",
            oldAmount,
            newAmount,
            balanceOf(account),
            block.number,
            now
        );

        return _IDStakesIndex[account];
    }

    /**
     * @dev remove liquidity provider
     *
     *
     * Emit {TrackingEvent} evt
     *
     * Requirements:
     *  only Is InOwners && stake must exist
     */
    function removeStake(address account)
        public
        onlyIsInOwners
        onlyStakeExist(account)
    {
        _Stakes[_IDStakesIndex[account]].flag = 2;
        _Stakes[_IDStakesIndex[account]].account = address(0);
        _Stakes[_IDStakesIndex[account]].tokena.amount = 0;
        _Stakes[_IDStakesIndex[account]].tokenb.amount = 0;
        _Stakes[_IDStakesIndex[account]].autoCompound = false;

        uint256 bl = balanceOf(account);

        if (bl > 0) {
            _burn(account, bl);
        }

        _StakeCount = _StakeCount.sub(1);

        emit TrackingEvent(
            account,
            "StakeRemoved",
            bl,
            0,
            balanceOf(account),
            block.number,
            now
        );
    }

    /**
     * @dev substract liquidity from provider
     *
     *
     * Emit {TrackingEvent} evt
     *
     * Requirements:
     *  only Is InOwners && stake must exist
     */

    function substractFromStake(address account, uint256 subAmount)
        external
        onlyIsInOwners
        onlyStakeExist(account)
        returns (uint256)
    {
        uint256 oldAmount = balanceOf(account);

        if (oldAmount == 0) {
            return _IDStakesIndex[account];
        }

        require(subAmount <= oldAmount, "1");

        _burn(account, subAmount);

        emit TrackingEvent(
            account,
            "StakeSubstracted",
            subAmount,
            0,
            balanceOf(account),
            block.number,
            now
        );
        return _IDStakesIndex[account];
    }

    /**
     * @dev Get provider liq. info by address
     *
     *
     * Returns:
     *      address of provider
     *      balance tokens
     *      reward tka qty
     *      reward tkb qty
     *      index
     *      is autocompound
     *
     */
    function getStake(address account)
        public
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        if (!StakeExist(account)) return (address(0), 0, 0, 0, 0, false);

        return (
            account,
            balanceOf(account),
            _Stakes[_IDStakesIndex[account]].tokena.amount,
            _Stakes[_IDStakesIndex[account]].tokenb.amount,
            _IDStakesIndex[account],
            _Stakes[_IDStakesIndex[account]].autoCompound
        );
    }

    /**
     * @dev Get provider liq. info by index
     *
     *
     * Returns:
     *      address of provider
     *      balance tokens
     *      reward tka qty
     *      reward tkb qty
     *      last blockNumber used  when update tka
     *      time stamp   when update tka
     *      last blockNumber used  when update tkb
     *      time stamp   when update tkb
     *      index
     *      is autocompound
     *
     */
    function getStakeByIndex(uint256 index)
        public
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        if (!_StakeExist(index))
            return (address(0), 0, 0, 0, 0, 0, 0, 0, false);

        Stake memory p = _Stakes[index];

        return (
            p.account,
            balanceOf(p.account),
            p.tokena.amount,
            p.tokenb.amount,
            p.tokena.block,
            p.tokena.ts,
            p.tokenb.block,
            p.tokenb.ts,
            p.autoCompound
        );
    }

    /**
     * @dev remove ALL liquidity provider
     *
     *
     * Emit {AllStakeRemoved} evt
     *
     * Requirements:
     *  only Is InOwners
     */

    function removeAllStake() external onlyIsInOwners returns (bool) {
        for (uint32 i = 0; i < (_lastIndexStakes + 1); i++) {
            _IDStakesIndex[_Stakes[i].account] = 0;

            address acc = _Stakes[i].account;
            _Stakes[i].flag = 0;
            _Stakes[i].account = address(0);
            _Stakes[i].tokena.amount = 0;
            _Stakes[i].tokenb.amount = 0;
            _Stakes[i].autoCompound = false;
            uint256 bl = balanceOf(acc);
            if (bl > 0) {
                _burn(acc, bl);
            }
        }
        _lastIndexStakes = 0;
        _StakeCount = 0;
        emit AllStakeRemoved();
        return true;
    }

    /**
     * @dev Get init blockNumber of account creation
     *
     */
    function getGenesisBlock(address account) public view returns (uint256) {
        if (!StakeExist(account)) return 0;

        return _Stakes[_IDStakesIndex[account]].genesisblock;
    }

    /** 
    * @dev Get init blockNumber of account creation
     *
     * Returns
     *      reward tka qty
     *      reward tkb qty
     *      last blockNumber used  when update tka
     *      time stamp   when update tka
     *      last blockNumber used  when update tkb
     *      time stamp   when update tkb
     *      index
     *      is autocompound

     */
    function getStakeRewards(address account)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        if (!StakeExist(account)) return (0, 0, 0, 0, 0, 0);

        return (
            _Stakes[_IDStakesIndex[account]].tokena.amount,
            _Stakes[_IDStakesIndex[account]].tokenb.amount,
            _Stakes[_IDStakesIndex[account]].tokena.block,
            _Stakes[_IDStakesIndex[account]].tokena.ts,
            _Stakes[_IDStakesIndex[account]].tokenb.block,
            _Stakes[_IDStakesIndex[account]].tokenb.ts
        );
    }

    /**
     * @dev Get auto compounds liq. provider status
     *
     */
    function getAutoCompoundStatus(address account) public view returns (bool) {
        if (!StakeExist(account)) return false;

        Stake memory p = _Stakes[_IDStakesIndex[account]];

        return p.autoCompound;
    }

    /**
     * @dev Set auto compounds liq. provider status
     *
     * Returns:
     *   index used
     *
     * Emit {TrackingEvent} evt
     *
     * Requirements:
     *  only Is InOwners  && stake must exist
     *
     *
     */
    function setAutoCompound(address account, bool active)
        public
        onlyIsInOwners
        onlyStakeExist(account)
        returns (uint256)
    {
        uint256 oldAmount = 0;
        uint256 newAmount = 0;

        if (_Stakes[_IDStakesIndex[account]].autoCompound) {
            oldAmount = 1;
        }

        _Stakes[_IDStakesIndex[account]].autoCompound = active;

        if (active) {
            newAmount = 1;
        }

        emit TrackingEvent(
            account,
            "AutoCompoundChanged",
            oldAmount,
            newAmount,
            balanceOf(account),
            block.number,
            now
        );
        return _IDStakesIndex[account];
    }

    /**
     * @dev Change reward amount
     * parameter set: 1=set value 2=add value  3=substract value
     * Returns:
     *   index used
     *
     * Emit {TrackingEvent} evt opt depend of  onlyChange status
     *
     * Requirements:
     *  only Is InOwners  && stake must exist
     *
     *
     */
    function changeReward(
        address account,
        uint256 rewardPending,
        uint256 amount,
        uint8 set,
        bool isTKA,
        bool onlyChange
    ) public onlyIsInOwners onlyStakeExist(account) returns (bool) {
        uint256 newrp;

        if (isTKA) {
            if (set == 1) {
                _Stakes[_IDStakesIndex[account]].tokena.amount = amount;

                newrp = rewardPending.sub(amount);
            }

            if (set == 2) {
                _Stakes[_IDStakesIndex[account]].tokena.amount = _Stakes[
                    _IDStakesIndex[account]
                ]
                    .tokena
                    .amount
                    .add(amount);
                newrp = rewardPending.sub(amount);
            }

            if (set == 3) {
                _Stakes[_IDStakesIndex[account]].tokena.amount = _Stakes[
                    _IDStakesIndex[account]
                ]
                    .tokena
                    .amount
                    .sub(amount);
                newrp = rewardPending.add(amount);
            }

            if (!onlyChange) {
                _Stakes[_IDStakesIndex[account]].tokena.block = block.number;
                _Stakes[_IDStakesIndex[account]].tokena.ts = now;
                emit TrackingEvent(
                    account,
                    "RewaredChanged_TKA",
                    amount,
                    newrp,
                    balanceOf(account),
                    block.number,
                    now
                );
            }
        } else {
            if (set == 1) {
                _Stakes[_IDStakesIndex[account]].tokenb.amount = amount;
                newrp = rewardPending.sub(amount);
            }

            if (set == 2) {
                _Stakes[_IDStakesIndex[account]].tokenb.amount = _Stakes[
                    _IDStakesIndex[account]
                ]
                    .tokenb
                    .amount
                    .add(amount);
                newrp = rewardPending.sub(amount);
            }

            if (set == 3) {
                _Stakes[_IDStakesIndex[account]].tokenb.amount = _Stakes[
                    _IDStakesIndex[account]
                ]
                    .tokenb
                    .amount
                    .sub(amount);
                newrp = rewardPending.add(amount);
            }

            if (!onlyChange) {
                _Stakes[_IDStakesIndex[account]].tokenb.block = block.number;
                _Stakes[_IDStakesIndex[account]].tokenb.ts = now;
                emit TrackingEvent(
                    account,
                    "RewaredChanged_TKB",
                    amount,
                    newrp,
                    balanceOf(account),
                    block.number,
                    now
                );
            }
        }

        return true;
    }
}
