// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @title AccountingTokens — Dimension 4 transparent accounting
/// @notice Soulbound (non-transferable) accounting instruments:
///         id 1 DONATION — non-spendable on-chain receipt minted to donors;
///         id 2 COMMONS — non-spendable indicator minted 1:1 per CHF of
///         tangible assets (Land, Products, Fiat) entering Gaia Commons.
///         Neither is purchasable, transferable, or grants governance power.
contract AccountingTokens is ERC1155 {
    uint256 public constant DONATION = 1;
    uint256 public constant COMMONS = 2;

    StewardRegistry public immutable stewards;
    /// @notice The treasury/multisig that issues receipts. Set at deploy.
    address public immutable issuer;

    error NonTransferable();
    error Unauthorized();
    error InvalidId(uint256 id);
    error ZeroAmount();

    constructor(StewardRegistry stewards_, string memory uri_) ERC1155(uri_) {
        stewards = stewards_;
        issuer = stewards_.multisig();
    }

    /// @notice Mint a DONATION receipt to `donor` for `amount` units of
    ///         contributed value (services valued at regular basic cost).
    function mintDonationReceipt(address donor, uint256 amount, bytes32 donationRef) external {
        _issue(DONATION, donor, amount, donationRef);
    }

    /// @notice Mint COMMONS indicator 1:1 per CHF of tangible assets entering
    ///         the commons (Land, Products, or Fiat — never time or services).
    function mintCommonsIndicator(uint256 amountChf, bytes32 assetRef) external {
        _issue(COMMONS, issuer, amountChf, assetRef);
    }

    function _issue(uint256 id, address to, uint256 amount, bytes32 ref) internal {
        if (amount == 0) revert ZeroAmount();
        stewards.consume(keccak256(abi.encode("ACCT_MINT", id, to, amount, ref)));
        _mint(to, id, amount, "");
    }

    /// @dev Accounting instruments are non-transferable between members.
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        if (from != address(0) && to != address(0)) revert NonTransferable();
        super._update(from, to, ids, values);
    }
}
