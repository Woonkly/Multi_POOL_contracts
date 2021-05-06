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
    function testCoinToToken() public payable {
        uint256 tokens_bought = coinToToken();

        Assert.equal(tokens_bought, 899190728344489, "FAIL testCoinToToken  ");
    }

    function testTokenToCoin() public {
        uint256 tk = 100000000000000;

        _token.doapprove(msg.sender, address(this), tk);

        uint256 ta = _tokenB.allowance(msg.sender, address(this));
        Assert.equal(ta, tk, "FAIL testTokenToCoin approve ");

        uint256 eth_bought = tokenToCoin(tk);

        Assert.equal(eth_bought, 90166822974832, "FAIL testTokenToCoin  ");
    }

    function testSendCOINtoContract() public payable {
        uint256 coin_reserve = getMyCoinBalance();

        Assert.equal(coin_reserve, 200, "FAIL testSendCOINtoContract ");
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
