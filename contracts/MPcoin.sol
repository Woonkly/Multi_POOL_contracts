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

contract MPcoin is MPbase {
    using SafeMath for uint256;

    //Section Type declarations

    //Section State variables
    uint256 public totalLiquidity;
    uint256 internal _coin_reserve;

    //Section Modifier

    //Section Events
    event PoolCreated(
        uint256 totalLiquidity,
        address investor,
        uint256 token_amount
    );
    event PoolClosed(
        uint256 eth_reserve,
        uint256 token_reserve,
        uint256 liquidity,
        address destination
    );
    event PurchasedTokens(
        address purchaser,
        uint256 coins,
        uint256 tokens_bought
    );

    event CollectRequested(address account, uint256 amount, bool isCoin);

    event TokensSold(address vendor, uint256 eth_bought, uint256 token_amount);

    event LiquidityChanged(
        address investor,
        uint256 tka,
        uint256 tkb,
        uint256 oldLiq,
        uint256 newliquidity
    );

    event CoinReceived(uint256 coins);

    //Section functions

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
        _coin_reserve = 0;
    }

    receive() external payable override {
        _coin_reserve = getMyCoinBalance();
        emit CoinReceived(msg.value);
    }

    function getMyCoinBalance() public view override returns (uint256) {
        address my = address(this);
        return my.balance;
    }

    function addCoin() external payable returns (bool) {
        _coin_reserve = getMyCoinBalance();
        return true;
    }

    function createPool(uint256 token_amount)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        require(
            _tokenB.allowance(_msgSender(), address(this)) >= token_amount,
            "1"
        );

        require(!_stakes.StakeExist(_msgSender()), "2");

        require(totalLiquidity == 0, "3");

        require(msg.value > 0, "4");

        totalLiquidity = getMyCoinBalance();
        _coin_reserve = totalLiquidity;

        _stakes.manageStake(_msgSender(), totalLiquidity);

        require(
            _tokenB.transferFrom(_msgSender(), address(this), token_amount)
        );

        _paused = false;

        emit PoolCreated(totalLiquidity, _msgSender(), token_amount);
        return totalLiquidity;
    }

    function migratePool(uint256 token_amount, uint256 newLiq)
        external
        payable
        onlyIsInOwners
        nonReentrant
        returns (uint256)
    {
        require(isPaused(), "1");

        require(
            _tokenB.allowance(_msgSender(), address(this)) >= token_amount,
            "2"
        );

        require(totalLiquidity == 0, "3");

        require(msg.value > 0, "4");

        totalLiquidity = newLiq;
        _coin_reserve = getMyCoinBalance();

        require(
            _tokenB.transferFrom(_msgSender(), address(this), token_amount)
        );
        _paused = false;
        emit PoolCreated(_coin_reserve, _msgSender(), token_amount);
        return totalLiquidity;
    }

    function closePool() external nonReentrant onlyIsInOwners returns (bool) {
        uint256 token_reserve = _tokenB.balanceOf(address(this));

        require(_tokenB.transfer(_operations, token_reserve), "1");

        address payable ow = address(uint160(_operations));

        _coin_reserve = getMyCoinBalance();
        ow.transfer(_coin_reserve);

        uint256 liq = totalLiquidity;
        totalLiquidity = 0;
        _coin_reserve = 0;
        _paused = true;
        emit PoolClosed(_coin_reserve, token_reserve, liq, ow);
        return true;
    }

    function isOverLimit(uint256 amount, bool isCOIN)
        public
        view
        returns (bool)
    {
        return (getPercImpact(amount, isCOIN) > 10);
    }

    function getPercImpact(uint256 amount, bool isCOIN)
        public
        view
        returns (uint8)
    {
        uint256 reserve = 0;

        if (isCOIN) {
            reserve = _coin_reserve;
        } else {
            reserve = _tokenB.balanceOf(address(this));
        }

        uint256 p = amount.mul(100).div(reserve);

        if (p <= 100) {
            return uint8(p);
        } else {
            return uint8(100);
        }
    }

    function getMaxAmountSwap() public view returns (uint256, uint256) {
        return (
            _coin_reserve.mul(10).div(100),
            _tokenB.balanceOf(address(this)).mul(10).div(100)
        );
    }

    function currentCoinToToken(uint256 token_amountA)
        public
        view
        returns (uint256)
    {
        return
            price(
                token_amountA,
                _coin_reserve,
                _tokenB.balanceOf(address(this))
            );
    }

    function currentTokentoCoin(uint256 token_amountB)
        public
        view
        returns (uint256)
    {
        return
            price(
                token_amountB,
                _tokenB.balanceOf(address(this)),
                _coin_reserve
            );
    }

    function _withdrawReward(
        address account,
        uint256 amount,
        bool isTKA
    ) internal returns (bool) {
        require(!isPaused(), "p");

        if (!_stakes.StakeExist(account)) {
            return false;
        }

        (, , uint256 tka, uint256 tkb, , ) = _stakes.getStake(account);

        uint256 remainder = 0;

        if (isTKA) {
            require(amount <= tka, "1");

            require(amount <= getMyCoinBalance(), "2");

            address(uint160(account)).transfer(amount);

            remainder = tka.sub(amount);
        } else {
            //token

            require(amount <= tkb, "3");

            require(amount <= getMyTokensBalance(_erc20B), "4");

            require(_tokenB.transfer(account, amount), "5");

            remainder = tkb.sub(amount);
        }

        _coin_reserve = getMyCoinBalance();

        substractRewPend(amount, isTKA);

        return _stakes.changeReward(account, 0, remainder, 1, isTKA, true);
    }

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

    function CollectReward(uint256 amount, bool isCoin)
        external
        payable
        nonReentrant
        returns (bool)
    {
        require(!isPaused(), "1");

        require(_stakes.StakeExist(_msgSender()), "2");

        require(msg.value >= _feeEXE, "3");

        address(uint160(_executor)).transfer(msg.value);

        emit CollectRequested(_msgSender(), amount, isCoin);

        return true;
    }

    function coinToToken() external payable nonReentrant returns (uint256) {
        require(!isPaused(), "p");

        require(totalLiquidity > 0, "1");

        require(!isOverLimit(msg.value, true), "2");

        uint256 token_reserve = _tokenB.balanceOf(address(this));

        uint256 tokens_bought = price(msg.value, _coin_reserve, token_reserve);

        uint256 tokens_bought0fee =
            planePrice(msg.value, _coin_reserve, token_reserve);

        _coin_reserve = getMyCoinBalance();

        require(tokens_bought <= getMyTokensBalance(_erc20B), "3");

        require(_tokenB.transfer(_msgSender(), tokens_bought), "4");

        emit PurchasedTokens(_msgSender(), msg.value, tokens_bought);

        uint256 tokens_fee = tokens_bought0fee - tokens_bought;

        (
            ,
            uint256 tokens_liqPart,
            uint256 tokens_opPart,
            uint256 tokens_stkPart
        ) = calcFees(tokens_fee);

        require(_tokenB.transfer(_beneficiary, tokens_stkPart), "6");

        require(_tokenB.transfer(_operations, tokens_opPart), "7");

        _rewPend = _rewPend.add(tokens_liqPart);

        _coin_reserve = getMyCoinBalance();

        _stakes.addReward(tokens_liqPart, false);

        return tokens_bought;
    }

    function tokenToCoin(uint256 token_amount)
        external
        nonReentrant
        returns (uint256)
    {
        require(!isPaused(), "p");

        require(
            _tokenB.allowance(_msgSender(), address(this)) >= token_amount,
            "0"
        );

        require(totalLiquidity > 0, "1");

        require(!isOverLimit(token_amount, false), "2");

        uint256 token_reserve = _tokenB.balanceOf(address(this));

        uint256 eth_bought = price(token_amount, token_reserve, _coin_reserve);

        uint256 eth_bought0fee =
            planePrice(token_amount, token_reserve, _coin_reserve);

        require(eth_bought <= getMyCoinBalance(), "3");

        _msgSender().transfer(eth_bought);

        _coin_reserve = getMyCoinBalance();

        require(
            _tokenB.transferFrom(_msgSender(), address(this), token_amount)
        );

        emit TokensSold(_msgSender(), eth_bought, token_amount);

        uint256 eth_fee = eth_bought0fee - eth_bought;

        (, uint256 eth_liqPart, uint256 eth_opPart, uint256 eth_stPart) =
            calcFees(eth_fee);

        address(uint160(_operations)).transfer(eth_opPart);

        address(uint160(_beneficiary)).transfer(eth_stPart);

        _coin_reserve = getMyCoinBalance();

        _rewPendTKA = _rewPendTKA.add(eth_liqPart);

        _stakes.addReward(eth_liqPart, true);

        return eth_bought;
    }

    function calcTokenBToAddLiq(uint256 coinDeposit)
        public
        view
        returns (uint256)
    {
        return
            (coinDeposit.mul(_tokenB.balanceOf(address(this))) / _coin_reserve)
                .add(1);
    }

    function AddLiquidity() external payable nonReentrant returns (uint256) {
        require(!isPaused(), "p");

        uint256 tka_reserve = _coin_reserve;

        uint256 tokenB_amount = calcTokenBToAddLiq(msg.value);

        require(
            _msgSender() != address(0) &&
                _tokenB.allowance(_msgSender(), address(this)) >= tokenB_amount,
            "1"
        );

        uint256 liquidity_minted =
            msg.value.mul(totalLiquidity).div(tka_reserve);

        _coin_reserve = getMyCoinBalance();

        _stakes.manageStake(_msgSender(), liquidity_minted);

        uint256 oldLiq = totalLiquidity;

        totalLiquidity = totalLiquidity.add(liquidity_minted);

        require(
            _tokenB.transferFrom(_msgSender(), address(this), tokenB_amount)
        );

        emit LiquidityChanged(
            _msgSender(),
            msg.value,
            tokenB_amount,
            oldLiq,
            totalLiquidity
        );

        return liquidity_minted;
    }

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

        uint256 tka_amount = liq.mul(_coin_reserve).div(totalLiquidity);
        uint256 tokenB_amount =
            liq.mul(_tokenB.balanceOf(address(this))).div(totalLiquidity);
        return (tka_amount, tokenB_amount);
    }

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

        tka_amount = inv.mul(_coin_reserve).div(totalLiquidity);
        tokenB_amount = inv.mul(tokenB_reserve).div(totalLiquidity);

        return (inv, tka_amount, tokenB_amount);
    }

    function _withdrawFunds(address account, uint256 liquid)
        internal
        returns (uint256, uint256)
    {
        require(_stakes.StakeExist(account), "1");

        (, uint256 inv_liq, , , , ) = _stakes.getStake(account);

        require(liquid <= inv_liq, "2");

        uint256 tokenB_reserve = _tokenB.balanceOf(address(this));

        uint256 tka_amount = liquid.mul(_coin_reserve).div(totalLiquidity);

        uint256 tokenB_amount = liquid.mul(tokenB_reserve).div(totalLiquidity);

        require(tka_amount <= getMyCoinBalance(), "3");

        require(tokenB_amount <= getMyTokensBalance(_erc20B), "4");

        _stakes.substractFromStake(account, liquid);

        uint256 oldLiq = totalLiquidity;

        totalLiquidity = totalLiquidity.sub(liquid);

        address(uint160(account)).transfer(tka_amount);

        _coin_reserve = getMyCoinBalance();

        require(_tokenB.transfer(account, tokenB_amount), "5");

        emit LiquidityChanged(
            account,
            tka_amount,
            tokenB_amount,
            oldLiq,
            totalLiquidity
        );

        return (tka_amount, tokenB_amount);
    }

    function WithdrawLiquidity(uint256 liquid)
        external
        nonReentrant
        returns (uint256, uint256)
    {
        require(!isPaused(), "p");

        require(totalLiquidity > 0, "6");

        require(_stakes.StakeExist(_msgSender()), "7");

        return _withdrawFunds(_msgSender(), liquid);
    }
}
