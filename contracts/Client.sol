// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; /* TODO */
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import {IPoolEscrow} from "./IPoolEscrow.sol";
import "./IPublicToken.sol";

contract Client is Context {

    using Address for address payable;

    address payable pool;
    IERC20Upgradeable stakedEthToken;
    // IERC20Upgradeable rewardEthToken;
    IPublicToken publicToken;
    IPoolEscrow escrow;

    constructor(address payable _pool,
                address payable _escrow,
                address _stakedEthToken,
                // address _rewardEthToken,
                address _publicToken
               ) {
        pool = _pool;
        stakedEthToken = IERC20Upgradeable(_stakedEthToken);
        // rewardEthToken = IERC20Upgradeable(_rewardEthToken);
        publicToken = IPublicToken(_publicToken);
        escrow = IPoolEscrow(_escrow);

        // The PoolEscrow contract should be able to take out the
        // desired Staked ETH amount on withdrawal requests.
        stakedEthToken.approve(_escrow, type(uint256).max);
    }

    function stake() external payable {
        pool.sendValue(msg.value);
        publicToken.mint(_msgSender(), msg.value);
    }

    // We receive ETH when withdrawing.
    receive() external payable {}    

    function request(uint256 amount) external {
        require(amount <= stakedEthToken.balanceOf(address(this)));
        publicToken.burnFrom(_msgSender(), amount);

        // Invoke PoolEscrow.request() and send to user any ETH
        // received from the Escrow contract.
        uint256 before = address(this).balance;
        escrow.request(amount, 0);
        uint256 after_ = address(this).balance;
        uint256 difference = after_ - before;
        if (difference > 0) {
            payable(_msgSender()).sendValue(difference);
        }
    }

    function withdraw(uint256 requestIndex) external {
        // Invoke PoolEscrow.withdraw() and send to user any ETH
        // received from the Escrow contract.
        uint256 before = address(this).balance;
        escrow.withdraw(requestIndex);
        uint256 after_ = address(this).balance;
        uint256 difference = after_ - before;
        if (difference > 0) {
            payable(_msgSender()).sendValue(difference);
        }
    }

}
