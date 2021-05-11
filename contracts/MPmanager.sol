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
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/utils/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/token/ERC20/ERC20.sol";
import "https://github.com/Woonkly/MartinHSolUtils/releasev34/OwnersLMH.sol";
import "https://github.com/Woonkly/MartinHSolUtils/releasev34/PausabledLMH.sol";
import "https://github.com/Woonkly/MartinHSolUtils/releasev34/BaseLMH.sol";
import "./MPLiquidityManager.sol";
import "./MPcoin.sol";
import "./MPtoken.sol";

contract MPmanager is PausabledLMH, ReentrancyGuard {
    using SafeMath for uint256;

    //Section Type declarations

    struct POOL {
        address owner;
        address pool;
        address tokena;
        address tokenb;
        uint256 amounta;
        uint256 amountb;
        bool isCOIN;
        bool isConfirmed;
        uint256 createdAt;
        uint8 flag; //0 no exist  1 exist 2 deleted
    }

    //Section State variables

    uint256 internal _lastIndexPools;
    mapping(uint256 => POOL) internal _Pools;
    uint256 internal _PoolsCount;
    uint256[] internal _pending;
    mapping(address => mapping(address => uint256)) private _poolspairs;
    mapping(address => uint256) private _poolindex;
    uint256 internal _depfee;
    address payable internal _executor;

    //Section Modifier

    //Section Events
    event DepFeeChanged(uint256 oldFee, uint256 newFee);
    event ExecutorChanged(address oldexe, address newexe);
    event addNewPool(
        address owner,
        address tka,
        address tkb,
        uint256 amounta,
        uint256 amountb,
        bool isCOIN,
        uint256 createdAt
    );
    event PoolRemoved(address tka, address tkb);
    event AllPoolsRemoved();
    event NewPoolCOINrequest(
        address tkb,
        address owner,
        uint256 amountb,
        uint256 indx
    );
    event NewPoolTOKENrequest(
        address tka,
        address tkb,
        address owner,
        uint256 amounta,
        uint256 amountb,
        uint256 indx
    );
    event PoolConfirmed(
        address pool,
        address tka,
        address tkb,
        uint256 amounta,
        uint256 amountb
    );

    //Section functions

    /**
     * @dev  Contract POOL manager
     *
     *
     * Parameter :
     *          executor: wallet executor dapp (is to collect fee to be able to execute functions from the dapp)
     *
     *
     *
     *
     */
    constructor(address payable executor) public {
        _executor = executor;

        _lastIndexPools = 0;
        _PoolsCount = 0;

        _depfee = 90000000000000000;
    }

    receive() external payable {
        // React to receiving ether
    }

    fallback() external payable {}

    /**
     * @dev  get base fee  necessary to be able to execute the deploy in the dapp
     *
     */
    function getDepFee() public view returns (uint256) {
        return _depfee;
    }

    /**
     * @dev set base fee  necessary to be able to execute the deploy in the dapp
     *
     * Emit {DepFeeChanged} evt
     *
     * Requirements:
     *      only Is InOwners require
     */

    function setDepFee(uint256 newFee) external onlyIsInOwners returns (bool) {
        uint256 old = _depfee;
        _depfee = newFee;
        emit DepFeeChanged(old, _depfee);
        return true;
    }

    /**
     * @dev  get executor dapp wallet
     *
     */
    function getExecutor() public view returns (address) {
        return _executor;
    }

    /**
     * @dev set address executor dapp wallet
     *
     * Emit {ExecutorChanged} evt
     *
     * Requirements:
     *      only Is InOwners require
     */
    function setExecutor(address payable newexe)
        external
        onlyIsInOwners
        returns (bool)
    {
        require(newexe != address(0), "1");
        address old = _executor;
        _executor = newexe;
        emit ExecutorChanged(old, _executor);
        return true;
    }

    /**
     * @dev  get the amount of pools
     *
     */
    function getPoolsCount() public view returns (uint256) {
        return _PoolsCount;
    }

    /**
     * @dev  get the last index pools map
     *
     */
    function getLastIndexPools() public view returns (uint256) {
        return _lastIndexPools;
    }

    /**
     * @dev  get if poolID exist
     *
     */
    function _PoolExist(uint256 PoolID) internal view returns (bool) {
        return (_Pools[PoolID].flag == 1);
    }

    /**
     * @dev  get if address pool exist here
     *
     */
    function PoolExist(address pool) public view returns (bool) {
        return _PoolExist(_poolindex[pool]);
    }

    /**
     * @dev  get if  pool exist here by tokens address
     *
     */
    function PoolExist(address tka, address tkb) public view returns (bool) {
        return _PoolExist(_poolspairs[tka][tkb]);
    }

    /**
     * @dev  get if  pool index exist here
     *
     */
    function PoolIndexExist(uint256 index) public view returns (bool) {
        return _PoolExist(index);
    }

    /**
     * @dev  register here the new pool added
     *
     * Returns new liquidity pool.
     *
     * Emit {addNewPool} evt.
     *
     */
    function _newPool(
        address owner,
        address tka,
        address tkb,
        uint256 amounta,
        uint256 amountb,
        bool isCOIN
    ) internal returns (uint256) {
        _lastIndexPools = _lastIndexPools.add(1);
        _PoolsCount = _PoolsCount.add(1);
        _Pools[_lastIndexPools].owner = owner;
        _Pools[_lastIndexPools].tokena = tka;
        _Pools[_lastIndexPools].tokenb = tkb;
        _Pools[_lastIndexPools].amounta = amounta;
        _Pools[_lastIndexPools].amountb = amountb;
        _Pools[_lastIndexPools].isConfirmed = false;
        _Pools[_lastIndexPools].isCOIN = isCOIN;
        _Pools[_lastIndexPools].createdAt = now;
        _Pools[_lastIndexPools].flag = 1;
        _poolspairs[tka][tkb] = _lastIndexPools;

        emit addNewPool(owner, tka, tkb, amounta, amountb, isCOIN, now);
        return _lastIndexPools;
    }

    /**
     * @dev  register here the new pool added
     *
     * Returns index of new  pool.
     *
     * Emit {addNewPool} evt.
     *
     * Parameters:
     *   address owner wallet creator
     *   address tka   erc20 contract addresss
     *   address tkb   erc20 contract addresss
     *   uint256 amounta  initial reserve amount
     *   uint256 amountb    initial reserve amount
     *   bool isCOIN    true is COIN (bnb/eth) with erc20 token
     * Requirements:
     *      only Is InOwners require not paused and pool not exist
     *
     * lock type: nonReentrant
     */
    function newPool(
        address owner,
        address tka,
        address tkb,
        uint256 amounta,
        uint256 amountb,
        bool isCOIN
    ) external onlyIsInOwners nonReentrant returns (uint256) {
        require(!isPaused());
        require(!PoolExist(tka, tkb));

        return _newPool(owner, tka, tkb, amounta, amountb, isCOIN);
    }

    /**
     * @dev  remove a registerd pool
     *
     * Returns new liquidity pool.
     *
     * Emit {PoolRemoved} evt.
     *
     * Parameters:
     *   address tka   erc20 contract addresss
     *   address tkb   erc20 contract addresss
     *
     * Requirements:
     *      only Is InOwners require  and pool  exist
     *
     * lock type: nonReentrant
     */
    function removePool(address tka, address tkb) external {
        require(OwnerExist(_msgSender()), "1");
        require(PoolExist(tka, tkb));

        _Pools[_lastIndexPools].owner = address(0);
        _Pools[_lastIndexPools].tokena = address(0);
        _Pools[_lastIndexPools].tokenb = address(0);
        _Pools[_lastIndexPools].pool = address(0);
        _Pools[_lastIndexPools].amounta = 0;
        _Pools[_lastIndexPools].amountb = 0;
        _Pools[_lastIndexPools].isConfirmed = false;
        _Pools[_lastIndexPools].isCOIN = false;
        _Pools[_lastIndexPools].createdAt = 0;
        _Pools[_lastIndexPools].flag = 2;

        _PoolsCount = _PoolsCount.sub(1);

        _poolspairs[tka][tkb] = 0;

        emit PoolRemoved(tka, tkb);
    }

    /**
     * @dev  get pool info by address pair tokens
     *
     *
     * Returns:
     *       p.pool: address pool
     *       p.owner: wallet creator
     *       p.tokena: address of erc20 token A
     *       p.tokenb: address of erc20 token B
     *       p.amounta: amount of erc20 token A
     *       p.amountb: amount of erc20 token B
     *       p.isCOIN: true is COIN / erc20 token pair
     *       p.isConfirmed: true if it was confirmed from the dapp
     *       p.createdAt: timestamp date creation
     *
     * Remarks: return all values 0 state if pool not exist
     */
    function getPool(address tka, address tkb)
        public
        view
        returns (
            address,
            address,
            address,
            address,
            uint256,
            uint256,
            bool,
            bool,
            uint256
        )
    {
        if (!PoolExist(tka, tkb))
            return (
                address(0),
                address(0),
                address(0),
                address(0),
                0,
                0,
                false,
                false,
                0
            );

        POOL memory p = _Pools[_poolspairs[tka][tkb]];

        return (
            p.pool,
            p.owner,
            p.tokena,
            p.tokenb,
            p.amounta,
            p.amountb,
            p.isCOIN,
            p.isConfirmed,
            p.createdAt
        );
    }

    /**
     * @dev  get pool info by index
     *
     *
     * Returns:
     *       p.pool: address pool
     *       p.owner: address wallet creator
     *       p.tokena: address of erc20 token A
     *       p.tokenb: address of erc20 token B
     *       p.amounta: amount of erc20 token A
     *       p.amountb: amount of erc20 token B
     *       p.isCOIN: true is COIN / erc20 token pair
     *       p.isConfirmed: true if it was confirmed from the dapp
     *       p.createdAt: timestamp date creation
     *       p.flag : flag state
     *
     * Remarks: return all values 0 state if pool not exist
     */
    function getPoolByIndex(uint256 index)
        public
        view
        returns (
            address,
            address,
            address,
            address,
            uint256,
            uint256,
            bool,
            bool,
            uint256,
            uint8
        )
    {
        if (!PoolIndexExist(index))
            return (
                address(0),
                address(0),
                address(0),
                address(0),
                0,
                0,
                false,
                false,
                0,
                0
            );

        POOL memory p = _Pools[index];

        return (
            p.pool,
            p.owner,
            p.tokena,
            p.tokenb,
            p.amounta,
            p.amountb,
            p.isCOIN,
            p.isConfirmed,
            p.createdAt,
            p.flag
        );
    }

    /**
     * @dev  get all registred pools
     *
     *
     * Returns:
     *       indexs: array  all pool index
     *       powners: array  all address wallet creators
     *       tkas: array  all address of erc20 tokens A
     *       tkbs: array  all address of erc20 tokens B
     *       iscons: array bool all confirmed pool state
     *
     * Remarks: return all emptys arrays if no pool
     */

    function getAllPools()
        public
        view
        returns (
            uint256[] memory,
            address[] memory,
            address[] memory,
            address[] memory,
            bool[] memory
        )
    {
        uint256[] memory indexs = new uint256[](_PoolsCount);
        address[] memory powners = new address[](_PoolsCount);
        address[] memory tkas = new address[](_PoolsCount);
        address[] memory tkbs = new address[](_PoolsCount);
        bool[] memory iscons = new bool[](_PoolsCount);

        uint256 ind = 0;

        for (uint32 i = 0; i < (_lastIndexPools + 1); i++) {
            POOL memory p = _Pools[i];
            if (p.flag == 1) {
                indexs[ind] = i;
                powners[ind] = p.pool;
                tkas[ind] = p.tokena;
                tkbs[ind] = p.tokenb;
                iscons[ind] = p.isConfirmed;
                ind++;
            }
        }

        return (indexs, powners, tkas, tkbs, iscons);
    }

    /**
     * @dev  remove all registed pools
     *
     *
     * Emit {AllPoolsRemoved} evt.
     *
     *
     * Requirements:
     *      only Is InOwners require
     *
     * lock type: nonReentrant
     */
    function removeAllPools()
        external
        onlyIsInOwners
        nonReentrant
        returns (bool)
    {
        for (uint32 i = 0; i < (_lastIndexPools + 1); i++) {
            _poolspairs[_Pools[i].tokena][_Pools[i].tokenb] = 0;

            _Pools[i].owner = address(0);
            _Pools[i].tokena = address(0);
            _Pools[i].tokenb = address(0);
            _Pools[i].pool = address(0);
            _Pools[i].amounta = 0;
            _Pools[i].amountb = 0;
            _Pools[i].isConfirmed = false;
            _Pools[i].isCOIN = false;
            _Pools[i].createdAt = 0;
            _Pools[i].flag = 0;
        }
        _lastIndexPools = 0;
        _PoolsCount = 0;
        emit AllPoolsRemoved();
        return true;
    }

    /**
     * @dev  get is pool pending for comfirmation
     *
     */
    function isIndexPendig(uint256 poolIndex) public view returns (bool) {
        bool exist = false;

        (exist, ) = _pendingEXIST(poolIndex);

        return exist;
    }

    /**
     * @dev  get all pending pool index (array)
     *
     */
    function getAllIndexPending() public view returns (uint256[] memory) {
        return _pending;
    }

    /**
     * @dev  get is pool pending for comfirmation by index
     *
     */
    function _pendingEXIST(uint256 poolIndex)
        internal
        view
        returns (bool, uint256)
    {
        if (_pending.length == 0) return (false, 0);

        uint256 i = 0;
        for (i = 0; i < _pending.length; i++) {
            if (_pending[i] == poolIndex) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    /**
     * @dev  ad new pending pool index
     *
     */
    function _addPendig(uint256 poolIndex) internal returns (bool) {
        bool exist = false;

        (exist, ) = _pendingEXIST(poolIndex);

        if (exist) {
            return false;
        }
        _pending.push(poolIndex);
        return true;
    }

    /**
     * @dev  remove from pendings (index pool)
     *
     *
     * Requirements:
     *      only Is InOwners require
     *
     */
    function removeindexPending(uint256 poolIndex) external returns (bool) {
        require(OwnerExist(_msgSender()), "1");
        return _removePending(poolIndex);
    }

    /**
     * @dev  remove from pendings (index pool)
     *
     *
     */
    function _removePending(uint256 poolIndex) internal returns (bool) {
        bool exist = false;
        uint256 ind = 0;

        (exist, ind) = _pendingEXIST(poolIndex);

        if (!exist) {
            return false;
        }

        _pending[ind] = _pending[_pending.length - 1];
        delete _pending[_pending.length - 1];

        return true;
    }

    /**
     * @dev  make new pool coin request call for dapp
     *
     *
     * Emit {NewPoolCOINrequest} evt.
     *
     *
     * Requirements:
     *    payable  only Is InOwners and no paused and pool not exist and extra charge _depfee
     *
     * lock type: nonReentrant
     */
    function newPoolCOINrequest(
        address tkb,
        uint256 amountcoin,
        uint256 amountb
    ) external payable nonReentrant returns (uint256) {
        require(!isPaused());
        require(!PoolExist(address(0), tkb));

        require(msg.value >= amountcoin.add(_depfee), "1");

        ERC20 _token = ERC20(tkb);
        require(_token.allowance(_msgSender(), address(this)) >= amountb, "2");

        require(_token.transferFrom(_msgSender(), address(this), amountb));

        uint256 indx =
            _newPool(_msgSender(), address(0), tkb, amountcoin, amountb, true);

        _Pools[indx].isConfirmed = false;

        _executor.transfer(_depfee);

        _addPendig(indx);

        emit NewPoolCOINrequest(tkb, _msgSender(), amountb, indx);
        return indx;
    }

    /**
     * @dev  make new pool token/token request call for dapp
     *
     *
     * Emit {NewPoolTOKENrequest} evt.
     *
     *
     * Requirements:
     *   payable   only Is InOwners and no paused and pool not exist require and extra charge _depfee
     *
     * lock type: nonReentrant
     */
    function newPoolTOKENrequest(
        address tka,
        address tkb,
        uint256 amounta,
        uint256 amountb
    ) external payable nonReentrant returns (uint256) {
        require(!isPaused());

        require(!PoolExist(tka, tkb));

        require(msg.value >= _depfee, "1");

        _executor.transfer(msg.value);

        ERC20 _tokenb = ERC20(tkb);
        ERC20 _tokena = ERC20(tka);

        require(_tokena.allowance(_msgSender(), address(this)) >= amounta, "2");
        require(_tokenb.allowance(_msgSender(), address(this)) >= amountb, "3");

        require(_tokena.transferFrom(_msgSender(), address(this), amounta));
        require(_tokenb.transferFrom(_msgSender(), address(this), amountb));

        uint256 indx =
            _newPool(_msgSender(), tka, tkb, amountb, amountb, false);

        _Pools[indx].isConfirmed = false;

        _addPendig(indx);

        emit NewPoolTOKENrequest(
            tka,
            tkb,
            _msgSender(),
            amounta,
            amountb,
            indx
        );
        return indx;
    }

    /**
     * @dev  after pool is created by dapp call this function to set confirmed pool creation
     *
     *
     * Emit {PoolConfirmed} evt.
     *
     *
     * Requirements:
     *      only Is InOwners and pool exist
     *
     * lock type: nonReentrant
     */

    function setConfirmedPool(uint256 indx, address payable pool)
        external
        nonReentrant
        returns (bool)
    {
        require(PoolIndexExist(indx), "1");
        require(OwnerExist(_msgSender()), "2");

        ERC20 _tokenb = ERC20(_Pools[indx].tokenb);

        if (_Pools[indx].isCOIN) {
            MPcoin poolCoin = MPcoin(pool);
            _tokenb.approve(pool, _Pools[indx].amountb);

            poolCoin.createPool{value: _Pools[indx].amounta}(
                _Pools[indx].amountb
            );
        } else {
            ERC20 _tokena = ERC20(_Pools[indx].tokena);

            _tokena.approve(pool, _Pools[indx].amounta);
            _tokenb.approve(pool, _Pools[indx].amountb);

            MPtoken poolToken = MPtoken(pool);

            poolToken.createPool(_Pools[indx].amounta, _Pools[indx].amountb);
        }

        _Pools[indx].pool = pool;
        _Pools[indx].isConfirmed = true;
        _poolindex[pool] = indx;

        emit PoolConfirmed(
            pool,
            _Pools[indx].tokena,
            _Pools[indx].tokenb,
            _Pools[indx].amounta,
            _Pools[indx].amountb
        );

        return true;
    }
}
