// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @title DonationCertNft — Donation Certification NFT (Dimension 4)
/// @notice Verifiable, non-transferable certificate issued to donors under
///         Option 2 so they can claim applicable tax exemptions. Records the
///         amount, receiving custodian entity, and designated fund/purpose.
contract DonationCertNft is ERC721 {
    struct Certificate {
        uint256 amountChf; // donated amount, 1e18 = 1 CHF
        uint64 issuedAt;
        string custodian; // receiving legal custodian entity (e.g. foundation)
        bytes32 purposeRef; // designated fund/purpose reference
    }

    StewardRegistry public immutable stewards;
    uint256 public nextId = 1;
    mapping(uint256 => Certificate) public certificates;

    event CertificateIssued(
        uint256 indexed tokenId,
        address indexed donor,
        uint256 amountChf,
        bytes32 indexed purposeRef
    );

    error NonTransferable();
    error ZeroAmount();

    constructor(StewardRegistry stewards_) ERC721("Gaia Donation Certificate", "GDNR") {
        stewards = stewards_;
    }

    /// @notice Issue a donation certificate after steward quorum approves
    ///         op hash keccak256("DONATION_CERT", donor, amountChf, custodian, purposeRef).
    function issue(
        address donor,
        uint256 amountChf,
        string calldata custodian,
        bytes32 purposeRef
    ) external returns (uint256 tokenId) {
        if (amountChf == 0) revert ZeroAmount();
        stewards.consume(
            keccak256(abi.encode("DONATION_CERT", donor, amountChf, custodian, purposeRef))
        );
        tokenId = nextId++;
        certificates[tokenId] = Certificate({
            amountChf: amountChf,
            issuedAt: uint64(block.timestamp),
            custodian: custodian,
            purposeRef: purposeRef
        });
        _mint(donor, tokenId);
        emit CertificateIssued(tokenId, donor, amountChf, purposeRef);
    }

    /// @dev Certificates are non-transferable credential receipts.
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
