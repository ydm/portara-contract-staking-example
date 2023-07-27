// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.16;

import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

interface IPoolEscrow is IERC165Upgradeable {
    /**
     * @notice Used to store requests that cannot be processed and
     * withdrawn instantly and require an off-chain action.  Those
     * requests can be later withdrawn using the `withdraw()`
     * function.
     */
    struct WithdrawalRequest {
        /**
         * @notice The total amount of ETH requested at the time of
         * request.
         */
        uint256 totalRequested;
        /**
         * @notice Here's how these are computed at the time of
         *         the request:
         *           a) grossPayment = sETH + rETH
         *           b) netPayment = grossPayment - fee
         *           c) deferredPayment = netPayment - immediatePayment
         */
        uint256 deferredPayment;
        address beneficiary;
    }

    // +-------------------+
    // | Events on request |
    // +-------------------+

    /**
     * @notice Emitted when a request is processed immediately.  No
     * `requests` entry is created in this case.
     *
     * netPayment
     *     = (sETH + rETH) - fee
     *     = immediatePayment
     */
    event InstantWithdrawalCompleted(
        uint256 stakedEthAmount,
        uint256 rewardEthAmount,
        uint256 immediatePayment, // Equal to netPayment.
        address indexed beneficiary
    );

    /*
     * @notice Emitted when a request can be processed partially
     * immediately and there's a deferred payment that requires
     * further off-chain action.
     *
     * netPayment
     *     = (sETH + rETH) - fee
     *     = immediatePayment + deferredPayment
     */
    // prettier-ignore
    event PartialWithdrawalRequested(
        uint256 requestIndex,
        uint256 stakedEthAmount,
        uint256 rewardEthAmount,
        uint256 immediatePayment,   // How much is sent at the time of request.
        uint256 deferredPayment,    // How much to be withdraw()n.
        uint256 pending,            // Total pending at the time of request.
        address indexed beneficiary // Who to pay.
    );

    /**
     * @notice Emitted when a request that cannot be processed
     * immediately is submitted.  A further off-chain action is
     * required to process the request and unlock the funds, which
     * then can be withdrawn using the `withdraw()` function.
     *
     * netPayment
     *     = (sETH + rETH) - fee
     *     = deferredPayment
     */
    // prettier-ignore
    event DeferredWithdrawalRequested(
        uint256 requestIndex,
        uint256 stakedEthAmount,
        uint256 rewardEthAmount,
        uint256 deferredPayment,    // Equal to netPayment.
        uint256 pending,            // Total pending at the time of request.
        address indexed beneficiary // Who to pay.
    );

    // +-----------------------+
    // | Configuration updates |
    // +-----------------------+

    event MinImmediatePaymentUpdated(uint256 oldMIP, uint256 newMIP);

    event WithdrawalFeeUpdated(uint256 oldFee, uint256 newFee);

    // +------+
    // | Misc |
    // +------+

    /**
     * @notice Emitted when fees are collected from the contract.
     *
     * @param collected The amount of `uncolectedFees` transferred
     *                  with this transaction.
     *
     * @param remaining The remaining amount of `uncollectedFees` in
     *                  the contract.
     *
     * @param collector The address of the account that collected the
     *                  fees.
     */
    event FeesCollected(uint256 collected, uint256 remaining, address collector);

    event WithdrawalCompleted(
        uint256 requestIndex,
        uint256 deferredPayment,
        address indexed beneficiary
    );

    /**
     * @notice Indicates that withdrawal requests in the range
     * [begin;end) have been processed and now can be claimed using
     * the withdraw(requestIndex) user function.
     */
    // prettier-ignore
    event RequestsProcessed(
        uint256 value,          // How much is sent with the tx.
        uint256 begin,          // Inclusive bound of newly processed requests.
        uint256 end,            // Exclusive bound of newly processed requests.
        address indexed sender  // Caller of the processRequests() fn.
    );

    event Restaked(uint256 value, address sender);

    // +-------------------------+
    // | Initializable constants |
    // +-------------------------+

    function pool() external view returns (address);

    function stakedEthToken() external view returns (address);

    function rewardEthToken() external view returns (address);

    // +------------------------+
    // | Configurable variables |
    // +------------------------+

    function minImmediatePayment() external view returns (uint256);

    function withdrawalFee() external view returns (uint256);

    // +-----------------+
    // | State variables |
    // +-----------------+

    function numProcessedRequests() external view returns (uint256);

    function totalRequested() external view returns (uint256);

    function totalWithdrawn() external view returns (uint256);

    function uncollectedFees() external view returns (uint256);

    function requests(
        uint256
    )
        external
        view
        returns (
            /* totalRequested */ uint256,
            /* deferredPayment */ uint256,
            /* beneficiary */ address
        );

    // +--------+
    // | System |
    // +--------+

    function initialize(address pool, address stakedEthToken, address rewardEthToken) external; // initializer

    function collectFees() external; // onlyAdmin

    function pause() external; // onlyAdmin

    function unpause() external; // onlyAdmin

    // grantRole() overriden from AccessControlUpgradeable
    // revokeRole() overriden from AccessControlUpgradeable
    // renounceRole() overriden from AccessControlUpgradeable

    function transferAdminRole(address account) external; // onlyAdmin

    function setMinImmediatePayment(uint256 value) external; // onlyAdmin

    function setWithdrawalFee(uint256 fee) external; // onlyAdmin

    // prettier-ignore
    function permitRequestFrom(
        address owner,
        uint deadline,
        uint8 sv, bytes32 sr, bytes32 ss,
        uint8 rv, bytes32 rr, bytes32 rs,
        uint256 stakedEthAmount,
        uint256 rewardEthAmount
    ) external; // onlyRequester

    function requestFrom(
        address beneficiary,
        uint256 stakedEthAmount,
        uint256 rewardEthAmount
    ) external; // onlyRequester whenNotPaused

    function restake(uint256 value) external; // onlyPooler

    function restakeAll() external; // onlyPooler

    // +--------+
    // | Public |
    // +--------+

    function processRequests(uint256 newNPR) external payable;

    receive() external payable;

    // prettier-ignore
    function permitTransfers(
        address owner,
        uint deadline,
        uint8 sv, bytes32 sr, bytes32 ss,
        uint8 rv, bytes32 rr, bytes32 rs
    ) external;

    function request(uint256 stakedEthAmount, uint256 rewardEthAmount) external; // whenNotPaused

    function withdraw(uint256 requestIndex) external; // whenNotPaused

    // +-------+
    // | Views |
    // +-------+

    function queueSize() external view returns (uint256);

    function nextRequestIndex() external view returns (uint256);

    function pending() external view returns (uint256);

    function availableBalance() external view returns (uint256);
}
