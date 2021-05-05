// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/GSN/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/utils/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/token/ERC20/ERC20.sol";
import "https://github.com/Woonkly/MartinHSolUtils/releasev34/OwnersLMH.sol";
import "https://github.com/Woonkly/MartinHSolUtils/releasev34/PausabledLMH.sol";
import "https://github.com/Woonkly/MartinHSolUtils/releasev34/BaseLMH.sol";
import "./MPLiquidityManager.sol";

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

contract MPbase is BaseLMH, PausabledLMH, ReentrancyGuard {
    using SafeMath for uint256;

    //Section Type declarations
    struct Stake {
        address account;
        uint256 liq;
        uint256 tokena;
        uint256 tokenb;
        uint8 flag;
    }
    struct processRewardInfo {
        uint256 remainder;
        uint256 woopsRewards;
        uint256 dealed;
        address me;
        bool resp;
    }

    //Section State variables
    IERC20 internal _tokenB;
    address internal _operations;
    address internal _beneficiary;
    address internal _executor;
    MPLiquidityManager internal _stakes;
    address internal _stakeable;
    uint256 internal _feeLIQ;
    uint256 internal _feeOperation;
    uint256 internal _feeSTAKE;
    uint256 internal _baseFee;
    bool internal _isBNBenv;
    address internal _erc20B;
    uint256 internal _rewPend = 0;
    uint256 internal _rewPendTKA = 0;
    uint256 internal _feeEXE = 0;

    //Section Modifier

    //Section Events
    event AddressChanged(address olda, address newa, uint8 id);
    event valueChanged(uint256 olda, uint256 newa, uint8 id);

    //Section functions
    /**
     * @dev Base constructor of POOL childrens
     *
     *Parameters:
     *   address erc20B             ERC20 address contract instance
     *   uint256 feeLIQ             fee is discounted for each swapp and partitioned between liquidity providers only (1..999) allowed
     *   uint256 feeOperation       fee is discounted for each swapp and send to operations account only (1..999) allowed
     *   uint256 feeSTAKE,          fee is discounted for each swapp and send to benef. account only (1..999) allowed
     *   address operations,        Account operations
     *   address beneficiary,       Account benef. to reward stakers liq. providers in STAKE contract
     *   address executor,          Account used for dapp to execute contracts functions where the fee is accumulated to be used in the dapp
     *   address stake,             LiquidityManager contract instance, store and manage all liq.providers
     *   bool isBNBenv              Set true is Binance blockchain (for future use)
     *
     * Requirements:
     *      (feeLIQ + feeOperation + feeSTAKE) === 1000 allowed  relation 1 to 100 %
     *
     * IMPORTANT:
     *          For the pool to be activated and working, the CreatePool function must be executed after deploying the contract
     */

    constructor(
        address erc20B,
        uint256 feeLIQ,
        uint256 feeOperation,
        uint256 feeSTAKE,
        address operations,
        address beneficiary,
        address executor,
        address stake,
        bool isBNBenv
    ) public {
        _erc20B = erc20B;
        _feeLIQ = feeLIQ;
        _feeOperation = feeOperation;
        _feeSTAKE = feeSTAKE;
        _beneficiary = beneficiary;
        _executor = executor;
        _operations = operations;
        _stakes = MPLiquidityManager(stake);
        _stakeable = stake;
        _isBNBenv = isBNBenv;
        _tokenB = IERC20(erc20B);
        _paused = true;
        _baseFee = 10000;
        _feeEXE = 418380000000000;
    }

    /**
     * @dev Get _isBNBenv
     *
     */
    function isBNB() public view returns (bool) {
        return _isBNBenv;
    }

    /**
     * @dev Get _beneficiary
     *
     */
    function getBeneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @dev get uint256,bool type values of store
     *
     *   uint256 feeLIQ             fee is discounted for each swapp and partitioned between liquidity providers only (1..999) allowed
     *   uint256 feeOperation       fee is discounted for each swapp and send to operations account only (1..999) allowed
     *   uint256 feeSTAKE           fee is discounted for each swapp and send to benef. account only (1..999) allowed
     *   uint256 _baseFee           Base for fee calculation
     *   uint256 _rewPend           Value store acum. total pendings rewards tokens
     *   uint256 _rewPendTKA        Value store acum. total pendings rewards coin
     *   uint256 _feeEXE            Fee this is transfer to executor acc. (for each swapp) to get money to  perform dapp contract function executions
     *   bool isBNBenv              Set true is Binance blockchain (for future use)
     *
     */
    function getValues()
        external
        view
        returns (
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
        return (
            _feeLIQ,
            _feeOperation,
            _feeSTAKE,
            _baseFee,
            _rewPend,
            _rewPendTKA,
            _feeEXE,
            _isBNBenv
        );
    }

    /**
     * @dev set uint256 type values store  according to the value of set
     *Parameters:
     * set equal to..
     *
     * 1  uint256 feeLIQ             fee is discounted for each swapp and partitioned between liquidity providers only (1..999) allowed
     * 2  uint256 feeOperation       fee is discounted for each swapp and send to operations account only (1..999) allowed
     * 3  uint256 feeSTAKE           fee is discounted for each swapp and send to benef. account only (1..999) allowed
     * 4  uint256 _baseFee           Base for fee calculation
     * 5  uint256 _rewPend           Value store acum. total pendings rewards tokens
     * 6  uint256 _rewPendTKA        Value store acum. total pendings rewards coin
     * 7  uint256 _feeEXE            Fee this is transfer to executor acc. (for each swapp) to get money to  perform dapp contract function executions
     *
     * Emit {valueChanged} evt
     *
     * Requirements:
     *      only Is InOwners require
     */

    function setValues(uint256 value, uint8 id)
        external
        onlyIsInOwners
        returns (bool)
    {
        uint256 old;

        if (id == 1) {
            require((value > 0 && value <= 1000000), "1");
            old = _feeLIQ;
            _feeLIQ = value;
        }

        if (id == 2) {
            require((value > 0 && value <= 1000000), "1");
            old = _feeOperation;
            _feeOperation = value;
        }

        if (id == 3) {
            require((value > 0 && value <= 1000000), "1");
            old = _feeSTAKE;
            _feeSTAKE = value;
        }

        if (id == 4) {
            require((value > 0 && value <= 1000000), "1");
            old = _baseFee;
            _baseFee = value;
        }

        if (id == 5) {
            old = _rewPend;
            _rewPend = value;
        }

        if (id == 6) {
            old = _rewPendTKA;
            _rewPendTKA = value;
        }

        if (id == 7) {
            old = _feeEXE;
            _feeEXE = value;
        }

        emit valueChanged(old, value, id);
        return true;
    }

    /**
     * @dev get address type values of store
     *
     *   address operations,        Operations wallet
     *   address beneficiary,       Benef. wallet to reward stakers liq. providers in STAKE contract
     *   address executor,          Wallet used for dapp to execute contracts functions where the fee is accumulated to be used in the dapp
     *   address stake,             LiquidityManager contract instance, store and manage all liq.providers
     *   address erc20B             ERC20 address contract instance
     *
     */
    function getAddress()
        external
        view
        returns (
            address,
            address,
            address,
            address,
            address
        )
    {
        return (_operations, _beneficiary, _executor, _stakeable, _erc20B);
    }

    /**
     * @dev set address type values store  according to the value of set
     *Parameters:
     * set equal to..
     *
     * 1  address operations,        Operations wallet
     * 2  address beneficiary,       Benef. wallet to reward stakers liq. providers in STAKE contract
     * 3  address executor,          Wallet used for dapp to execute contracts functions where the fee is accumulated to be used in the dapp
     * 4  address stake,             LiquidityManager contract instance, store and manage all liq.providers
     * 5  address erc20B             ERC20 address contract instance
     *
     * Emit {AddressChanged} evt
     *
     * Requirements:
     *      only Is InOwners require
     */
    function setAddress(address newa, uint8 id)
        external
        onlyIsInOwners
        returns (bool)
    {
        require(newa != address(0), "1");

        address old;

        if (id == 1) {
            old = _operations;
            _operations = newa;
        }

        if (id == 2) {
            old = _beneficiary;
            _beneficiary = newa;
        }

        if (id == 3) {
            old = _executor;
            _executor = newa;
        }

        if (id == 4) {
            old = _stakeable;
            _stakeable = newa;
            _stakes = MPLiquidityManager(newa);
        }

        if (id == 5) {
            old = _erc20B;
            _erc20B = newa;
            _tokenB = IERC20(_erc20B);
        }

        emit AddressChanged(old, newa, id);
        return true;
    }

    /**
     * @dev get sum of all _feeXX to perform master fee calculation
     *
     */
    function getFee() internal view returns (uint256) {
        uint256 fee = _feeLIQ + _feeSTAKE + _feeOperation;
        if (fee > _baseFee) {
            return 0;
        }

        return _baseFee - fee;
    }

    /**
     * @dev get swapp price with the discounted fee
     *
     */
    function price(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) public view returns (uint256) {
        uint256 input_amount_with_fee = input_amount.mul(uint256(getFee()));
        uint256 numerator = input_amount_with_fee.mul(output_reserve);
        uint256 denominator =
            input_reserve.mul(_baseFee).add(input_amount_with_fee);
        return numerator.div(denominator);
    }

    /**
     * @dev get swapp price with no fee
     *
     */
    function planePrice(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) public view returns (uint256) {
        uint256 input_amount_with_fee0 = input_amount.mul(uint256(_baseFee));
        uint256 numerator = input_amount_with_fee0.mul(output_reserve);
        uint256 denominator =
            input_reserve.mul(_baseFee).add(input_amount_with_fee0);
        return numerator.div(denominator);
    }

    /**
     * @dev get the Calculate the amount fees corresponding to each sector
     *
     *      uint256 remanider amount
     *      uint256 amount for liq providers
     *      uint256 amount for operations
     *      uint256 amount for stakers rewards
     *
     */
    function calcFees(uint256 amount)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 totFee = _feeLIQ + _feeSTAKE + _feeOperation;

        uint256 liq = amount.mul(_feeLIQ).div(totFee);
        uint256 oper = amount.mul(_feeOperation).div(totFee);
        uint256 stake = amount.mul(_feeSTAKE).div(totFee);
        uint256 remainder = amount - (liq + oper + stake);

        return (remainder, liq, oper, stake);
    }

    /**
     * @dev get the Calculate the amount correspondig to liq provider
     *
     *      uint256 part amount
     *      uint256 remainder
     *
     */
    function getCalcRewardAmount(
        address account,
        uint256 amount,
        uint256 totalLiquidity
    ) public view returns (uint256, uint256) {
        if (!_stakes.StakeExist(account)) return (0, 0);

        (, uint256 liq, , , , ) = _stakes.getStake(account);

        uint256 part = (liq * amount).div(totalLiquidity);

        return (part, amount - part);
    }

    /**
     * @dev Substract from reward pending acum.
     *
     *      bool isTKA is cthe coin part
     *
     */
    function substractRewPend(uint256 amount, bool isTKA)
        internal
        returns (bool)
    {
        if (isTKA != true) {
            if (_rewPend >= amount) {
                _rewPend = _rewPend.sub(amount);
            } else {
                _rewPend = 0;
            }
        } else {
            if (_rewPendTKA >= amount) {
                _rewPendTKA = _rewPendTKA.sub(amount);
            } else {
                _rewPendTKA = 0;
            }
        }
    }
}
