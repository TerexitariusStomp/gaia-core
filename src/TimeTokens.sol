// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @title TimeTokens — the Human & Operational Value Triad (Dimension 3)
/// @notice HREGEN (ecological restoration), HSOCIAL (care/education/cohesion),
///         and KHRONOS (operations/logistics) as ERC-1155 ids 1–3.
///         One verified hour = one token. They cannot be purchased with fiat,
///         carry 0% demurrage, and are minted only by a quorum of certified
///         Treasury Stewards after the dual-verification of logged hours.
contract TimeTokens is ERC1155 {
    uint256 public constant HREGEN = 1;
    uint256 public constant HSOCIAL = 2;
    uint256 public constant KHRONOS = 3;

    /// @notice No contributor may log more than this many verified hours/week.
    uint256 public constant WEEKLY_HOURS_CAP = 48;

    StewardRegistry public immutable stewards;

    /// @notice ISO week (`timestamp / 7 days`) => contributor => hours logged.
    mapping(uint256 => mapping(address => uint256)) public weeklyHours;

    event HoursMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 hours_,
        bytes32 indexed evidenceRef
    );

    error InvalidId(uint256 id);
    error ZeroAmount();
    error WeeklyCapExceeded(uint256 week, uint256 logged, uint256 requested);

    constructor(StewardRegistry stewards_, string memory uri_) ERC1155(uri_) {
        stewards = stewards_;
    }

    /// @notice Mint tokens for verified hours after a steward quorum approves
    ///         op hash keccak256("HOURS_MINT", to, id, hours, evidenceRef).
    /// @param to Contributor being credited.
    /// @param id One of HREGEN / HSOCIAL / KHRONOS.
    /// @param hours_ Verified hours (1 token per hour, 18 decimals each).
    /// @param evidenceRef Hash of the GI3CF evidence record (E2–E4 tier).
    function mintVerifiedHours(
        address to,
        uint256 id,
        uint256 hours_,
        bytes32 evidenceRef
    ) external {
        if (id < HREGEN || id > KHRONOS) revert InvalidId(id);
        if (hours_ == 0) revert ZeroAmount();
        uint256 week = block.timestamp / 7 days;
        uint256 logged = weeklyHours[week][to];
        if (logged + hours_ > WEEKLY_HOURS_CAP) {
            revert WeeklyCapExceeded(week, logged, hours_);
        }
        weeklyHours[week][to] = logged + hours_;

        stewards.consume(keccak256(abi.encode("HOURS_MINT", to, id, hours_, evidenceRef)));
        _mint(to, id, hours_ * 1e18, "");
        emit HoursMinted(to, id, hours_, evidenceRef);
    }

    /// @notice Burn contribution tokens (e.g. redeemed at the Gaia ReSources Bank).
    function redeem(uint256 id, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        _burn(msg.sender, id, amount);
    }
}
