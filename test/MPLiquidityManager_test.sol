// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <0.9.0;
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "remix_accounts.sol";
import "../contracts/MPLiquidityManager.sol";

contract testMPLiquidityManager is MPLiquidityManager {
    constructor() public MPLiquidityManager("testMPLiquidityManager", "TEST") {}

    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeAll() public {
        // Here should instantiate tested contract
        Assert.equal(uint256(1), uint256(1), "1 should be equal to 1");
    }

    function testNewStake() public {
        newStake(TestsAccounts.getAccount(1), 10**18, 1, 2, false);

        Assert.equal(getStakeCount(), 1, "FAIL to create newStake");

        (
            address acc,
            uint256 liq,
            uint256 tka,
            uint256 tkb,
            uint256 index,
            bool autoc
        ) = getStake(TestsAccounts.getAccount(1));

        Assert.equal(
            acc,
            TestsAccounts.getAccount(1),
            "FAIL to create newStake acc "
        );
        Assert.equal(liq, 10**18, "FAIL to create newStake liq ");
        Assert.equal(tka, 1, "FAIL to create newStake tka ");
        Assert.equal(tkb, 2, "FAIL to create newStake tkb ");
        Assert.equal(autoc, false, "FAIL to create newStake autocompound ");
    }

    function testManageStake() public {
        manageStake(TestsAccounts.getAccount(1), 10**18);
        (, uint256 liq, , , , ) = getStake(TestsAccounts.getAccount(1));
        Assert.equal(liq, 10**18 * 2, "FAIL to manage Stake liq ");
    }

    function testTransferStake() public {
        transferStake(TestsAccounts.getAccount(1), TestsAccounts.getAccount(2));
        (, uint256 liq, , , , ) = getStake(TestsAccounts.getAccount(2));
        Assert.equal(liq, 10**18 * 2, "FAIL to transfer Stake liq ");
    }

    function testRenewStake() public {
        renewStake(TestsAccounts.getAccount(2), 10**18);
        (, uint256 liq, , , , ) = getStake(TestsAccounts.getAccount(2));
        Assert.equal(liq, 10**18, "FAIL to renewStake Stake liq ");
    }

    function testSubstractFromStake() public {
        substractFromStake(TestsAccounts.getAccount(2), 1);
        (, uint256 liq, , , , ) = getStake(TestsAccounts.getAccount(2));
        Assert.equal(
            liq,
            (10**18) - 1,
            "FAIL to substractFromStake Stake liq "
        );
    }

    function testSetAutoCompound() public {
        setAutoCompound(TestsAccounts.getAccount(2), true);
        (, , , , , bool autoc) = getStake(TestsAccounts.getAccount(2));
        Assert.equal(autoc, true, "FAIL to setAutoCompound auto ");
    }

    function testChangeRewardTKA() public {
        changeReward(TestsAccounts.getAccount(2), 100, 50, 1, true, true);

        (, , uint256 tka, , , ) = getStake(TestsAccounts.getAccount(2));

        Assert.equal(tka, 50, "FAIL to changeReward tka op 1 ");

        changeReward(TestsAccounts.getAccount(2), 100, 10, 2, true, true);

        (, , tka, , , ) = getStake(TestsAccounts.getAccount(2));

        Assert.equal(tka, 60, "FAIL to changeReward tka op 2 ");

        changeReward(TestsAccounts.getAccount(2), 100, 10, 3, true, true);

        (, , tka, , , ) = getStake(TestsAccounts.getAccount(2));

        Assert.equal(tka, 50, "FAIL to changeReward tka op 3 ");
    }

    function testChangeRewardTKB() public {
        changeReward(TestsAccounts.getAccount(2), 100, 50, 1, false, true);

        (, , , uint256 tkb, , ) = getStake(TestsAccounts.getAccount(2));

        Assert.equal(tkb, 50, "FAIL to changeReward tkb op 1 ");

        changeReward(TestsAccounts.getAccount(2), 100, 10, 2, false, true);

        (, , , tkb, , ) = getStake(TestsAccounts.getAccount(2));

        Assert.equal(tkb, 60, "FAIL to changeReward tkb op 2 ");

        changeReward(TestsAccounts.getAccount(2), 100, 10, 3, false, true);

        (, , , tkb, , ) = getStake(TestsAccounts.getAccount(2));

        Assert.equal(tkb, 50, "FAIL to changeReward tkb op 3 ");
    }

    function testRemoveAllStake() public {
        removeAllStake();

        Assert.equal(getStakeCount(), 0, "FAIL testRemoveAllStake");
    }

    function testAddReward() public {
        addReward(10**18, true);
        addReward(10**18, false);

        (uint256 amount, , ) = getTotalReward(true);

        Assert.equal(amount, 10**18, "FAIL testAddReward tka ");

        (amount, , ) = getTotalReward(false);

        Assert.equal(amount, 10**18, "FAIL testAddReward tkb ");
    }

    function testSubReward() public {
        subReward(1, true);
        subReward(1, false);

        (uint256 amount, , ) = getTotalReward(true);

        Assert.equal(amount, (10**18) - 1, "FAIL subReward tka ");

        (amount, , ) = getTotalReward(false);

        Assert.equal(amount, (10**18) - 1, "FAIL subReward tkb ");
    }
}
