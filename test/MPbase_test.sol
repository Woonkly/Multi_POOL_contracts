// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <0.9.0;
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "remix_accounts.sol";
import "../contracts/MPbase.sol";
import "./MockMPLiquidityManager.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testMPbase is MPbase {
    MockMPLiquidityManager cstm;

    constructor()
        public
        MPbase(
            0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8,
            571,
            143,
            286,
            TestsAccounts.getAccount(9),
            TestsAccounts.getAccount(8),
            TestsAccounts.getAccount(7),
            0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B,
            true
        )
    {}

    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeAll() public {
        /*
            first deploy 2 instances of MockERC20tk and MockMPLiquidityManager
        */
        cstm = MockMPLiquidityManager(
            0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B
        );
        cstm.MockaddOwner(address(this));
    }

    function testCalcPricesAndFeesAndRewards() public {
        uint256 val = price(10000, 100000000, 100000000);

        Assert.equal(val, 8999, "FAIL to calc price ");

        val = planePrice(10000, 100000000, 100000000);

        Assert.equal(val, 9999, "FAIL to calc planePrice ");

        (uint256 remainder, uint256 liq, uint256 oper, uint256 stake) =
            calcFees(_baseFee / 10);

        Assert.equal(remainder, 0, "FAIL to calcFees remainder ");
        Assert.equal(liq, _feeLIQ, "FAIL to calcFees liq ");
        Assert.equal(oper, _feeOperation, "FAIL to calcFees oper ");
        Assert.equal(stake, _feeSTAKE, "FAIL to calcFees stake ");

        (uint256 part, uint256 remainder2) =
            getCalcRewardAmount(
                0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
                10**10,
                10**18
            );

        Assert.equal(part, 1000000000, "FAIL  getCalcRewardAmount  part");
        Assert.equal(
            remainder2,
            9000000000,
            "FAIL  getCalcRewardAmount remainder2"
        );
    }

    function testSetValues() public {
        uint256 val;

        (
            uint256 _feeLIQ,
            uint256 _feeOperation,
            uint256 _feeSTAKE,
            uint256 _baseFee,
            uint256 _rewPend,
            uint256 _rewPendTKA,
            uint256 _feeEXE,
            bool _isBNBenv
        ) = getValues();

        setValues(1, 1);
        (val, , , , , , , ) = getValues();
        Assert.equal(val, 1, "FAIL to setValues _feeLIQ ");
        setValues(_feeLIQ, 1);

        setValues(1, 2);
        (, val, , , , , , ) = getValues();
        Assert.equal(val, 1, "FAIL to setValues _feeOperation ");
        setValues(_feeOperation, 2);

        setValues(1, 3);
        (, , val, , , , , ) = getValues();
        Assert.equal(val, 1, "FAIL to setValues _feeSTAKE ");
        setValues(_feeSTAKE, 3);

        setValues(1, 4);
        (, , , val, , , , ) = getValues();
        Assert.equal(val, 1, "FAIL to setValues _baseFee ");
        setValues(_baseFee, 4);

        setValues(1, 5);
        (, , , , val, , , ) = getValues();
        Assert.equal(val, 1, "FAIL to setValues _rewPend ");
        setValues(_rewPend, 5);

        setValues(1, 6);
        (, , , , , val, , ) = getValues();
        Assert.equal(val, 1, "FAIL to setValues _rewPendTKA ");
        setValues(_rewPendTKA, 6);

        setValues(1, 7);
        (, , , , , , val, ) = getValues();
        Assert.equal(val, 1, "FAIL to setValues _feeEXE ");
        setValues(_feeEXE, 7);
    }

    function testSetAddress() public {
        address val;

        (
            address _operations,
            address _beneficiary,
            address _executor,
            address _stakeable,
            address _erc20B
        ) = getAddress();
        setAddress(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 1);
        (val, , , , ) = getAddress();
        Assert.equal(
            val,
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
            "FAIL to setValues _operations "
        );
        setAddress(_operations, 1);

        setAddress(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 2);
        (, val, , , ) = getAddress();
        Assert.equal(
            val,
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
            "FAIL to setValues _beneficiary "
        );
        setAddress(_beneficiary, 2);

        setAddress(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 3);
        (, , val, , ) = getAddress();
        Assert.equal(
            val,
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
            "FAIL to setValues _executor "
        );
        setAddress(_executor, 3);

        setAddress(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 4);
        (, , , val, ) = getAddress();
        Assert.equal(
            val,
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
            "FAIL to setValues _stakeable "
        );
        setAddress(_stakeable, 4);

        setAddress(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 5);
        (, , , , val) = getAddress();
        Assert.equal(
            val,
            0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
            "FAIL to setValues _erc20B "
        );
        setAddress(_erc20B, 5);
    }
}
