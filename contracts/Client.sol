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

    mapping(address /* user */ => uint256 /* deferredPayment */) payments;

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

        // In case of instant or partial withdrawal, there's an
        // immediate payment.
        uint256 immediate = after_ - before;
        require(immediate <= amount);

        // The rest of the total amount is deferred.
        uint256 deferred = amount - immediate;
        if (deferred > 0) {
            payments[_msgSender()] += deferred;
        }

        // Finally, send the immediate payment to the user.
        if (immediate > 0) {
            payable(_msgSender()).sendValue(immediate);
        }
    }

    function withdraw(uint256 requestIndex) external {
        // Invoke PoolEscrow.withdraw() and send to user any ETH
        // received from the Escrow contract.
        uint256 before = address(this).balance;
        escrow.withdraw(requestIndex);
        uint256 after_ = address(this).balance;
        uint256 deferred = after_ - before;

        if (deferred > 0) {
            // Once we have the deferred payment as an exact amount,
            // make sure the user is eligible for this withdrawal.
            // Otherwise a user would be able to withdraw other users'
            // tickets.
            address sender = _msgSender();
            require(payments[sender] > deferred);
            payments[sender] -= deferred;

            // Send the deferred payment to the user.
            payable(_msgSender()).sendValue(deferred);
            delete payments[sender];
        }
    }

}
