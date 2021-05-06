// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <0.9.0;
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "remix_accounts.sol";
import "../contracts/MPcoin.sol";
import "./MockMPLiquidityManager.sol";
import "./MockERC20tk.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testMPcoin is MPcoin {
    MockMPLiquidityManager cstm;
    MockERC20tk _token;

    constructor()
        public
        MPcoin(
            0xd9145CCE52D386f254917e481eB44e9943F39138,
            571,
            143,
            286,
            TestsAccounts.getAccount(9),
            TestsAccounts.getAccount(8),
            TestsAccounts.getAccount(7),
            0xf8e81D47203A594245E36C48e151709F0C19fBe8,
            true
        )
    {}

    function beforeAll() public {
        // Here should instantiate tested contract
        /*
            first deploy 2 instances of MockERC20tk and MockMPLiquidityManager
        */
        cstm = MockMPLiquidityManager(
            0xf8e81D47203A594245E36C48e151709F0C19fBe8
        );
        cstm.MockaddOwner(address(this));
        _token = MockERC20tk(_erc20B);
    }

    /// #value: 1000000000000000000
    function testSendCreatePool() public payable {
        Assert.equal(
            msg.sender,
            TestsAccounts.getAccount(0),
            "FAIL msg.sender != TestsAccounts.getAccount(0) "
        );

        Assert.equal(
            cstm.OwnerExist(address(this)),
            true,
            "FAIL testSendCreatePool cstm.OwnerExist "
        );

        uint256 tk = 1000000000000000000;

        _token.doapprove(msg.sender, address(this), tk);

        uint256 ta = _tokenB.allowance(msg.sender, address(this));
        Assert.equal(ta, tk, "FAIL testSendCreatePool approve ");

        if (cstm.StakeExist(msg.sender)) {
            cstm.removeStake(msg.sender);
        }

        Assert.equal(
            cstm.StakeExist(msg.sender),
            false,
            "FAIL testSendCreatePool StakeExist "
        );

        Assert.equal(
            totalLiquidity,
            0,
            "FAIL testSendCreatePool totalLiquidity "
        );

        Assert.greaterThan(
            msg.value,
            uint256(0),
            "FAIL testSendCreatePool msg.value > 0 "
        );

        createPool(tk);

        Assert.equal(_paused, false, "FAIL testSendCreatePool pause ");
        Assert.equal(
            totalLiquidity,
            msg.value,
            "FAIL testSendCreatePool totalLiquidity "
        );
    }

    /// #value: 1000000000000000
    /// #sender: account-3
    function testLiquidity() public payable {
        Assert.equal(
            msg.sender,
            TestsAccounts.getAccount(3),
            "FAIL testAddLiquidity not acc3 "
        );

        uint256 tk = calcTokenBToAddLiq(msg.value);

        _token.domint(msg.sender, tk);

        uint256 bl = _token.balanceOf(msg.sender);

        Assert.greaterThan(bl, tk - 1, "FAIL testAddLiquidity domint ");

        _token.doapprove(msg.sender, address(this), tk);

        uint256 ta = _tokenB.allowance(msg.sender, address(this));

        Assert.equal(tk, ta, "FAIL testAddLiquidity approve ");

        Assert.equal(_paused, false, "FAIL testAddLiquidity pause ");

        uint256 liquidity_minted = AddLiquidity();

        Assert.equal(
            liquidity_minted,
            1000000000000000,
            "FAIL testAddLiquidity  "
        );

        (, uint256 liq, , , , ) = _stakes.getStake(msg.sender);

        Assert.equal(
            liq,
            1000000000000000,
            "FAIL to testAddLiquidity Stake liq "
        );

        (uint256 tka_amount, uint256 tokenB_amount) =
            WithdrawLiquidity(liquidity_minted);

        (, uint256 liq2, , , , ) = _stakes.getStake(msg.sender);

        Assert.equal(
            liq,
            1000000000000000,
            "FAIL to WithdrawLiquidity Stake liq "
        );

        cstm.removeStake(msg.sender);
    }

    function testClosePool() public {
        closePool();
        Assert.equal(_paused, true, "FAIL testClosePool pause ");
        cstm.removeFromOwners(address(this));
        Assert.equal(
            cstm.OwnerExist(address(this)),
            false,
            "FAIL testClosePool cstm.OwnerExist "
        );
    }
}
