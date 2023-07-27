// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPublicToken is IERC20 {
    function mint(address account, uint256 amount) external /* onlyClient */;
    function burnFrom(address account, uint256 amount) external /* onlyClient */;
}
