# Multi_POOL_contracts
Contracts for the creation and management of DEFI pools formed by pairs coin - erc20 token and token erc20 -erc20 token: The functions of each pool include buying and selling (swapp) and adding and removing liquidity by liquidity providers. Users who add liquidity (STAKE) are benefited with part of the fee charged in each purchase and sale transaction (swapp)



Brief description:

MPcoin.sol Template contract for the creation of pools containing coin / erc20 tokens

MP.token Template contract for the creation of pools containing erc20 / erc20 tokens

MPmanager.sol: It is responsible for registering the new pools created, and interacting with the dapp to coordinate the deployment and confirmation of the pool contracts.


Iteration cycle:
                    send
MPmanager.sol ---> NewPoolCOINrequest / NewPoolTokenrequest evt ---> DAPP (listen for new evts) 

*******************  Depoloy new pool contract  (executor wallet use _depfee charge to deploy, init and confirm)
*******************  Init new pool contract

MPmanager.sol <----   call setConfirmedPool() <--------------call setConfirmedPool to confirm


Deal rewards for liquidity providers:
It is administered from the rewards dapp from where a percentage of the fee taken from each swapp is distributed to each liquidity provider in proportion to the aggregate liquidity, then it can be withdrawn by the liquidity provider through the interaction between the dapp and the pools:

Iteration cycle:

Pool-----> CollectRequested(_msgSender(), amount, isTKA) --> DAPP (listen for new evts) (executor wallet use _depfee charge to gets calls)

****************************  DAPP check and transfer pending reward to end user wallet                               

Pool <-----------------------   WithdrawRewardDAPP() call <---- DAPP confirm ok transfer

