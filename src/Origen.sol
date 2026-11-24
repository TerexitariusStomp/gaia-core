// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @title Origen (ORI)
/// @notice Dimension-1 real-asset-backed token: 1 ORI anchors 1 CHF of real
///         production cost for verified goods entering the Gaia ReSources Bank
///         or Gaia Market. Minting requires a quorum of certified Treasury
///         Stewards; there is no speculative issuance path.
contract Origen is ERC20 {
    StewardRegistry public immutable stewards;

    event BackedMint(address indexed to, uint256 amount, bytes32 indexed assetRef);
    event BurnedForGoods(address indexed from, uint256 amount, bytes32 indexed redemptionRef);

    error ZeroAmount();

    constructor(StewardRegistry stewards_) ERC20("Gaia ORIGEN", "ORI") {
        stewards = stewards_;
    }

    /// @notice Mint ORI against a verified real asset at production cost.
    /// @param to Recipient (treasury for donated assets, participant for purchases).
    /// @param amount ORI amount, 1 wei-ORI per wei-CHF of production cost.
    /// @param assetRef Opaque reference to the audited asset/inventory record.
    function mintBacked(address to, uint256 amount, bytes32 assetRef) external {
        if (amount == 0) revert ZeroAmount();
        bytes32 op = keccak256(abi.encode("ORI_MINT", to, amount, assetRef));
        stewards.consume(op);
        _mint(to, amount);
        emit BackedMint(to, amount, assetRef);
    }

    /// @notice Redeem ORI for goods/services — tokens are burned on redemption.
    function redeem(uint256 amount, bytes32 redemptionRef) external {
        if (amount == 0) revert ZeroAmount();
        _burn(msg.sender, amount);
        emit BurnedForGoods(msg.sender, amount, redemptionRef);
    }
}
