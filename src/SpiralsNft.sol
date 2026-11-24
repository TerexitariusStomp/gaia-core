// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @title SpiralsNft — Dimension 5 direct project support recognition
/// @notice Soulbound diploma minted when a contribution funds a project whose
///         assets offer public rental/leasing services. It codifies NO yield:
///         the discretionary "Reciprocity of Intention" airdrops the project
///         may make over time are recorded on-chain as events, never promised
///         amounts, never payable in fiat, and never a claim on the commons.
contract SpiralsNft is ERC721 {
    StewardRegistry public immutable stewards;
    uint256 public nextId = 1;

    /// @notice project reference each diploma recognizes support for.
    mapping(uint256 => bytes32) public projectOf;
    /// @notice contribution recognized by each diploma (1e18 = 1 CHF).
    mapping(uint256 => uint256) public recognizedAmount;

    event DiplomaIssued(
        uint256 indexed tokenId,
        address indexed supporter,
        bytes32 indexed projectRef,
        uint256 recognizedAmount
    );
    /// @notice Discretionary reciprocity actually delivered — recorded for
    ///         transparency. Emitted only when an airdrop is executed; no
    ///         cadence or amount is promised anywhere in this contract.
    event ReciprocityGranted(
        uint256 indexed tokenId,
        address indexed token,
        uint256 amount,
        bytes32 indexed note
    );

    error NonTransferable();
    error ZeroAmount();

    constructor(StewardRegistry stewards_) ERC721("Gaia SPIRALS", "SPR") {
        stewards = stewards_;
    }

    /// @notice Issue a support diploma after steward quorum approves op hash
    ///         keccak256("SPIRALS_ISSUE", supporter, projectRef, amount).
    /// @param amount CHF-denominated contribution being recognized (1e18 = 1 CHF).
    function issue(
        address supporter,
        bytes32 projectRef,
        uint256 amount
    ) external returns (uint256 tokenId) {
        if (amount == 0) revert ZeroAmount();
        stewards.consume(keccak256(abi.encode("SPIRALS_ISSUE", supporter, projectRef, amount)));
        tokenId = nextId++;
        projectOf[tokenId] = projectRef;
        recognizedAmount[tokenId] = amount;
        _mint(supporter, tokenId);
        emit DiplomaIssued(tokenId, supporter, projectRef, amount);
    }

    /// @notice Record a discretionary reciprocity airdrop granted to a diploma
    ///         holder. Callable only after steward quorum approves op hash
    ///         keccak256("SPIRALS_GRANT", tokenId, token, amount, note).
    ///         Gaia tokens only — never fiat — and never on a schedule.
    function recordReciprocity(
        uint256 tokenId,
        address token,
        uint256 amount,
        bytes32 note
    ) external {
        _requireOwned(tokenId);
        stewards.consume(keccak256(abi.encode("SPIRALS_GRANT", tokenId, token, amount, note)));
        emit ReciprocityGranted(tokenId, token, amount, note);
    }

    /// @dev Diplomas are non-transferable recognition certificates.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) revert NonTransferable();
        return super._update(to, tokenId, auth);
    }
}
