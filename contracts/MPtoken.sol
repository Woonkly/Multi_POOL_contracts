// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/math/SafeMath.sol";
import "./MPbase.sol";

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

contract MPtoken is MPbase {
    using SafeMath for uint256;

    //Section Type declarations

    //Section State variables
    uint256 public totalLiquidity;
    IERC20 internal _tokenA;
    address internal _erc20A;

    //Section Modifier

    //Section Events

    event CollectRequested(address account, uint256 amount, bool isTKA);

    event TokenAChanged(address old, address news);
    event PoolCreated(
        uint256 totalLiquidity,
        address investor,
        uint256 token_amountA,
        uint256 token_amountB
    );

    event PoolClosed(
        uint256 tkA_reserve,
        uint256 tkB_reserve,
        uint256 liquidity,
        address destination
    );

    event PurchasedTokens(
        address purchaser,
        uint256 coins,
        uint256 tokens_bought
    );
    event TokensSold(address vendor, uint256 eth_bought, uint256 token_amount);

    event LiquidityChanged(
        address investor,
        uint256 tka,
        uint256 tkb,
        uint256 oldLiq,
        uint256 newliquidity
    );

    //Section functions

    /**
     * @dev Constructor of ERC20 (token A) / ERC20 pool (token B)
     *
     * Parameters:
     *   address erc20A             ERC20 address contract instance
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
        address erc20A,
        address erc20B,
        uint256 feeLIQ,
        uint256 feeOperation,
        uint256 feeSTAKE,
        address operations,
        address beneficiary,
        address executor,
        address stake,
        bool isBNBenv
    )
        public
        MPbase(
            erc20B,
            feeLIQ,
            feeOperation,
            feeSTAKE,
            operations,
            beneficiary,
            executor,
            stake,
            isBNBenv
        )
    {
        _erc20A = erc20A;
        _tokenA = IERC20(erc20A);
    }

    /**
     * @dev  get token A address
     *
     */
    function getTokenAAddr() public view returns (address) {
        return _erc20A;
    }

    /**
     * @dev set address tokenA a inicialize instance
     *
     * Emit {TokenAChanged} evt
     *
     * Requirements:
     *      only Is InOwners require
     */
    function setTokenAAddr(address news)
        external
        onlyIsInOwners
        returns (bool)
    {
        require(news != address(0), "0");
        address old = _erc20A;
        _erc20A = news;
        _tokenA = ERC20(news);
        emit TokenAChanged(old, news);
        return true;
    }

    /**
     * @dev  Inicialize pool instance
     *      reverts for any transfer failure
     *
     * Returns new liquidity pool.
     *
     * Emit {PoolCreated} evt.
     *
     * Requirements:
     *      payable && _tokenA.allowance && _tokenB.allowance &&  totalLiquidity == 0 && (msg.value > 0
     *
     * lock type: nonReentrant
     */
    function createPool(uint256 tokenA_amount, uint256 tokenB_amount)
        external
        nonReentrant
        returns (uint256)
    {
        require(
            _tokenA.allowance(_msgSender(), address(this)) >= tokenA_amount,
            "1"
        );
        require(
            _tokenB.allowance(_msgSender(), address(this)) >= tokenB_amount,
            "2"
        );

        require(!_stakes.StakeExist(_msgSender()), "3");

        require(totalLiquidity == 0, "4");

        totalLiquidity = tokenA_amount;

        _stakes.manageStake(_msgSender(), tokenA_amount);

        require(
            _tokenA.transferFrom(_msgSender(), address(this), tokenA_amount)
        );
        require(
            _tokenB.transferFrom(_msgSender(), address(this), tokenB_amount)
        );

        _paused = false;

        emit PoolCreated(
            totalLiquidity,
            _msgSender(),
            tokenA_amount,
            tokenB_amount
        );
        return totalLiquidity;
    }

    /**
     * @dev  Migrate from other pool
     *      reverts for any transfer failure
     *
     * Returns new liquidity pool.
     *
     * Emit {PoolCreated} evt.
     *
     * Requirements:
     *     only is owner  && _tokenA.allowance && _tokenB.allowance &&  totalLiquidity == 0 && (msg.value > 0
     *
     * lock type: nonReentrant
     *
     * IMPORTANT:
     *      tokenA_Amount and tokenB_Amount  must be exact token balance older pool amount
     *      newLiq must be exact to older pool liquidity
     *
     */
    function migratePool(
        uint256 tokenA_amount,
        uint256 tokenB_amount,
        uint256 newLiq
    ) external onlyIsInOwners nonReentrant returns (uint256) {
        require(isPaused(), "1");

        require(totalLiquidity == 0, "2");

        require(
            _tokenA.allowance(_msgSender(), address(this)) >= tokenA_amount,
            "3"
        );

        require(
            _tokenB.allowance(_msgSender(), address(this)) >= tokenB_amount,
            "4"
        );

        totalLiquidity = newLiq;

        require(
            _tokenA.transferFrom(_msgSender(), address(this), tokenA_amount)
        );

        require(
            _tokenB.transferFrom(_msgSender(), address(this), tokenB_amount)
        );

        _paused = false;

        emit PoolCreated(
            totalLiquidity,
            _msgSender(),
            tokenA_amount,
            tokenB_amount
        );
        return totalLiquidity;
    }

    /**
     * @dev  Close and desactivacte this pool
     *      reverts for any transfer failure
     *
     *
     * Emit {PoolClosed} evt.
     *
     * Requirements:
     *    only is owner
     *
     * lock type: nonReentrant
     *
     * IMPORTANT:
     *      Is set to pause cannot suitable for swapp or liquidity operations
     *      All funds (tokens A & B) are transfered to operation wallet
     *      liquidity pool is set to 0
     *
     */
    function closePool() external nonReentrant onlyIsInOwners returns (bool) {
        uint256 tka = _tokenA.balanceOf(address(this));
        require(_tokenA.transfer(_operations, tka));

        uint256 tkb = _tokenB.balanceOf(address(this));
        require(_tokenB.transfer(_operations, tkb));

        emit PoolClosed(tka, tkb, totalLiquidity, _operations);

        totalLiquidity = 0;

        _paused = true;

        return true;
    }

    /**
     * @dev  Calculate that the amount to be used does not exceed 10%
     *
     * parameter: isTKA true if token A amount
     *
     * Return true is ower 10% limit
     *
     */
    function isOverLimit(uint256 amount, bool isTKA)
        public
        view
        returns (bool)
    {
        return (getPercImpact(amount, isTKA) > 10);
    }

    /**
     * @dev  Calculate % Of estimated total impact on liquidity
     *
     * parameter: isTKA true if token A amount
     */
    function getPercImpact(uint256 amount, bool isTKA)
        public
        view
        returns (uint8)
    {
        uint256 reserve = 0;

        if (isTKA) {
            reserve = _tokenA.balanceOf(address(this));
        } else {
            reserve = _tokenB.balanceOf(address(this));
        }

        uint256 p = amount.mul(100).div(reserve);

        if (p <= 100) {
            return uint8(p);
        }
        return uint8(100);
    }

    /**
     * @dev  Calculate an return the maximum amount allowed to use
     *
     */
    function getMaxAmountSwap() public view returns (uint256, uint256) {
        return (
            _tokenA.balanceOf(address(this)).mul(10).div(100),
            _tokenB.balanceOf(address(this)).mul(10).div(100)
        );
    }

    /**
     * @dev  Calculates the amount of tokensB to be delivered based on the amount of tokenA receive (swapp)
     *
     */
    function currentAtoB(uint256 tokenA_amount) public view returns (uint256) {
        return
            price(
                tokenA_amount,
                _tokenA.balanceOf(address(this)),
                _tokenB.balanceOf(address(this))
            );
    }

    /**
     * @dev  Calculates the amount of tokensA to be delivered based on the amount of tokensB receive (swapp)
     *
     */
    function currentBtoA(uint256 tokenB_amount) public view returns (uint256) {
        return
            price(
                tokenB_amount,
                _tokenB.balanceOf(address(this)),
                _tokenA.balanceOf(address(this))
            );
    }

    /**
     * @dev  Make the withdrawal of the reward to the user's wallet (only for internal contract calls)
     *      reverts for any transfer failure
     *
     * Parameter : isTKA If true to token A withdraw
     *
     * Requirements:
     *    not isPaused && _stakes.StakeExist
     *
     *
     */
    function _withdrawReward(
        address account,
        uint256 amount,
        bool isTKA
    ) internal returns (bool) {
        require(_stakes.StakeExist(account), "1");

        (, , uint256 tka, uint256 tkb, , ) = _stakes.getStake(account);

        uint256 remainder = 0;

        if (isTKA) {
            require(amount <= tka, "2");

            require(amount <= getMyTokensBalance(_erc20A), "3");

            require(_tokenA.transfer(account, amount), "4");

            remainder = tka.sub(amount);
        } else {
            //token

            require(amount <= tkb, "5");

            require(amount <= getMyTokensBalance(_erc20B), "6");

            require(_tokenB.transfer(account, amount), "7");

            remainder = tkb.sub(amount);
        }

        substractRewPend(amount, isTKA);

        return _stakes.changeReward(account, 0, remainder, 1, isTKA, true);
    }

    /**
     * @dev  Make the withdrawal of the reward to the user's wallet
     *      reverts for any transfer failure
     *
     * Parameter : isTKA If true to token A withdraw
     *
     * Requirements:
     *    not isPaused
     *
     * lock type: nonReentrant
     *
     */
    function WithdrawReward(uint256 amount, bool isTKA)
        external
        nonReentrant
        returns (bool)
    {
        require(!isPaused(), "p");

        require(_stakes.StakeExist(_msgSender()), "1");

        _withdrawReward(_msgSender(), amount, isTKA);

        return true;
    }

    /**
     * @dev  Make the collect of pendig rew. and withdrawal the reward to the user's wallet
     *      reverts for any transfer failure
     *
     * Parameter :
     *      isTKA If true to token A withdraw
     *      rewardPending: calculated form dapp of pending reward
     *
     * Requirements:
     *    only Is InOwners
     *
     * lock type: nonReentrant
     *
     */
    function WithdrawRewardDAPP(
        address account,
        uint256 rewardPending,
        uint256 amount,
        bool isTKA
    ) external nonReentrant onlyIsInOwners returns (bool) {
        require(_stakes.StakeExist(account), "2");

        _stakes.changeReward(account, rewardPending, amount, 2, isTKA, false);

        _withdrawReward(account, amount, isTKA);

        return true;
    }

    /**
     * @dev  Make the collect of pendig rew to reward liq. user
     *      reverts for any transfer failure
     *
     * Parameter :
     *      isTKA: If true to token A withdraw
     *      amount: calculated form dapp of pending reward
     *
     * Requirements:
     *    payable {_fee} for dapp executions contracts calls
     *
     * lock type: nonReentrant
     *
     */
    function CollectReward(uint256 amount, bool isTKA)
        external
        payable
        nonReentrant
        returns (bool)
    {
        require(!isPaused(), "1");

        require(_stakes.StakeExist(_msgSender()), "2");

        require(msg.value >= _feeEXE, "3");

        address(uint160(_executor)).transfer(msg.value);

        emit CollectRequested(_msgSender(), amount, isTKA);

        return true;
    }

    /**
     * @dev  Make the token A to token B swapp an transfer to user wallet
     *      reverts for any transfer failure
     *
     * Requirements:
     *    not paused  && totalLiquidity > 0 && not isOverLimit && _tokenA.allowance
     *
     * Emit {PurchasedTokens} evt.
     *
     * lock type: nonReentrant
     *
     */
    function sellTokenB(uint256 tka_amount)
        external
        nonReentrant
        returns (uint256)
    {
        require(!isPaused(), "p");

        require(
            _tokenA.allowance(_msgSender(), address(this)) >= tokena_amount,
            "0"
        );

        require(totalLiquidity > 0, "1");

        require(!isOverLimit(tka_amount, true), "2");

        uint256 tokenb_reserve = _tokenB.balanceOf(address(this));

        uint256 tokens_bought =
            price(tka_amount, getMyTokensBalance(_erc20A), tokenb_reserve);

        uint256 tokens_bought0fee =
            planePrice(tka_amount, getMyTokensBalance(_erc20A), tokenb_reserve);

        require(tokens_bought <= getMyTokensBalance(_erc20B), "3");

        require(
            _tokenA.allowance(_msgSender(), address(this)) >= tka_amount,
            "4"
        );

        require(_tokenA.transferFrom(_msgSender(), address(this), tka_amount));

        require(_tokenB.transfer(_msgSender(), tokens_bought), "5");

        emit PurchasedTokens(_msgSender(), tka_amount, tokens_bought);

        uint256 tokens_fee = tokens_bought0fee - tokens_bought;

        //(remainder, liq, oper, stake);

        (
            ,
            uint256 tokens_liqPart,
            uint256 tokens_opPart,
            uint256 tokens_stkPart
        ) = calcFees(tokens_fee);

        require(_tokenB.transfer(_beneficiary, tokens_stkPart), "6");
        require(_tokenB.transfer(_operations, tokens_opPart), "7");

        _rewPend = _rewPend.add(tokens_liqPart);

        _stakes.addReward(tokens_liqPart, false);

        return tokens_bought;
    }

    /**
     * @dev  Make the token B to token A swapp an transfer to user wallet
     *      reverts for any transfer failure
     *
     * Requirements:
     *     not paused  && totalLiquidity > 0 && not isOverLimit &&  _tokenB.allowance
     *
     * Emit {PurchasedTokens} evt.
     *
     * lock type: nonReentrant
     *
     */
    function sellTokenA(uint256 tokenb_amount)
        external
        nonReentrant
        returns (uint256)
    {
        require(!isPaused(), "p");

        require(
            _tokenB.allowance(_msgSender(), address(this)) >= tokenb_amount,
            "0"
        );

        require(totalLiquidity > 0, "1");

        require(!isOverLimit(tokenb_amount, false), "2");

        uint256 tokenb_reserve = _tokenB.balanceOf(address(this));

        uint256 tka_bought =
            price(
                tokenb_amount,
                tokenb_reserve,
                _tokenA.balanceOf(address(this))
            );

        uint256 tka_bought0fee =
            planePrice(
                tokenb_amount,
                tokenb_reserve,
                _tokenA.balanceOf(address(this))
            );

        require(tka_bought <= getMyTokensBalance(_erc20A), "3");

        require(_tokenA.transfer(_msgSender(), tka_bought), "4");

        require(
            _tokenB.transferFrom(_msgSender(), address(this), tokenb_amount),
            "5"
        );

        emit TokensSold(_msgSender(), tka_bought, tokenb_amount);

        uint256 tka_fee = tka_bought0fee - tka_bought;

        (, uint256 tka_liqPart, uint256 tka_opPart, uint256 tka_stPart) =
            calcFees(tka_fee);

        require(_tokenA.transfer(_beneficiary, tka_stPart), "6");

        require(_tokenA.transfer(_operations, tka_opPart), "7");

        _rewPendTKA = _rewPendTKA.add(tka_liqPart);

        _stakes.addReward(tka_liqPart, true);

        return tka_bought;
    }

    /**
     * @dev get the Calculates the necesary amount of token in base of token A added for add liquidity operation
     *
     */
    function calcTokenBToAddLiq(uint256 tokenA) public view returns (uint256) {
        return
            (
                tokenA.mul(_tokenB.balanceOf(address(this))).div(
                    _tokenA.balanceOf(address(this))
                )
            )
                .add(1);
    }

    /**
     * @dev  Add liquidity to porvider
     *      reverts for any transfer failure
     *
     * Requirements:
     *      not paused   &&  _tokenB.allowance &&  _tokenA.allowance
     *
     * Emit {LiquidityChanged} evt.
     *
     * lock type: nonReentrant
     *
     */
    function AddLiquidity(uint256 tokenA_amount)
        external
        nonReentrant
        returns (uint256)
    {
        require(!isPaused(), "p");

        uint256 tka_reserve = _tokenA.balanceOf(address(this));

        uint256 tokenB_amount = calcTokenBToAddLiq(tokenA_amount);

        require(
            _msgSender() != address(0) &&
                _tokenB.allowance(_msgSender(), address(this)) >= tokenB_amount,
            "1"
        );

        require(
            _tokenA.allowance(_msgSender(), address(this)) >= tokenA_amount,
            "2"
        );

        uint256 liquidity_minted =
            tokenA_amount.mul(totalLiquidity).div(tka_reserve);

        _stakes.manageStake(_msgSender(), liquidity_minted);

        uint256 oldLiq = totalLiquidity;

        totalLiquidity = totalLiquidity.add(liquidity_minted);

        require(
            _tokenA.transferFrom(_msgSender(), address(this), tokenA_amount)
        );

        require(
            _tokenB.transferFrom(_msgSender(), address(this), tokenB_amount)
        );

        emit LiquidityChanged(
            _msgSender(),
            tokenA_amount,
            tokenB_amount,
            oldLiq,
            totalLiquidity
        );

        return liquidity_minted;
    }

    /**
     * @dev Calculates the amount of token A - token B that user can withdraw in base of liq amount
     *
     */
    function getValuesLiqWithdraw(address investor, uint256 liq)
        public
        view
        returns (uint256, uint256)
    {
        if (!_stakes.StakeExist(investor)) {
            return (0, 0);
        }

        (, uint256 inv, , , , ) = _stakes.getStake(investor);

        if (liq > inv) {
            return (0, 0);
        }

        uint256 tka_amount =
            liq.mul(_tokenA.balanceOf(address(this))).div(totalLiquidity);
        uint256 tokenB_amount =
            liq.mul(_tokenB.balanceOf(address(this))).div(totalLiquidity);
        return (tka_amount, tokenB_amount);
    }

    /**
     * @dev Calculates the MAX amount of token A - token B that user can withdraw
     *
     */
    function getMaxValuesLiqWithdraw(address investor)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        if (!_stakes.StakeExist(investor)) {
            return (0, 0, 0);
        }

        uint256 tokenB_reserve = _tokenB.balanceOf(address(this));

        uint256 tka_amount;
        uint256 tokenB_amount;

        (, uint256 inv, , , , ) = _stakes.getStake(investor);

        tka_amount = inv.mul(_tokenA.balanceOf(address(this))).div(
            totalLiquidity
        );
        tokenB_amount = inv.mul(tokenB_reserve).div(totalLiquidity);

        return (inv, tka_amount, tokenB_amount);
    }

    /**
     * @dev  Make the liquidity withdrawal   (only for internal contract calls)
     *      reverts for any transfer failure
     *
     * Parameter : liquid amount to substract
     *
     * Returns:
     *      token A & token B amount transfered
     *
     * Emit {LiquidityChanged} evt.
     *
     * Requirements:
     *    liq provider exist && retired  <= invested
     *
     *
     */
    function WithdrawLiquidity(uint256 liquid)
        external
        nonReentrant
        returns (uint256, uint256)
    {
        require(!isPaused(), "p");

        require(totalLiquidity > 0, "1");

        require(_stakes.StakeExist(_msgSender()), "2");

        (, uint256 inv_liq, , , , ) = _stakes.getStake(_msgSender());

        require(liquid <= inv_liq, "3");

        uint256 tokenB_reserve = _tokenB.balanceOf(address(this));

        uint256 tka_amount =
            liquid.mul(_tokenA.balanceOf(address(this))).div(totalLiquidity);

        uint256 tokenB_amount = liquid.mul(tokenB_reserve).div(totalLiquidity);

        require(tka_amount <= getMyTokensBalance(_erc20A), "4");

        require(tokenB_amount <= getMyTokensBalance(_erc20B), "5");

        _stakes.substractFromStake(_msgSender(), liquid);

        uint256 oldLiq = totalLiquidity;

        totalLiquidity = totalLiquidity.sub(liquid);

        require(_tokenA.transfer(_msgSender(), tka_amount), "6");

        require(_tokenB.transfer(_msgSender(), tokenB_amount), "7");

        emit LiquidityChanged(
            _msgSender(),
            tka_amount,
            tokenB_amount,
            oldLiq,
            totalLiquidity
        );

        return (tka_amount, tokenB_amount);
    }
}
