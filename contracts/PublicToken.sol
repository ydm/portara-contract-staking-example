// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IPublicToken.sol";

contract PublicToken is IPublicToken, AccessControl, ERC20Burnable {

    bytes32 public constant CLIENT_ROLE = keccak256("PublicToken::CLIENT_ROLE");

    modifier onlyClient() {
        _checkRole(CLIENT_ROLE);
        _;
    }

    constructor() ERC20("Public Token", "PT") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function mint(address account, uint256 amount) external override onlyClient {
        super._mint(account, amount);
    }

    function burn(uint256 amount) public override {
        // NOOP
    }

    function burnFrom(address account, uint256 amount) public override (IPublicToken, ERC20Burnable) onlyClient {
        super.burnFrom(account, amount);
    }

}
