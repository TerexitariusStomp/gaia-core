// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @title TrokenAyni — Dimension-2 inter-regional mutual credit
/// @notice Interest-free mutual credit: balances may go negative down to the
///         member's credit limit. New members start with a 33-unit line
///         (calibrated to ~1 kg / 30 units of eggs of purchasing power);
///         stewards may extend it up to the hard cap. Clearing cycles run
///         12 months; uncollectible negative balances are covered by the
///         commons surplus pool, not by interest.
/// @dev ERC-20-shaped surface, but balances may be negative — `balanceOf`
///      returns the positive part; `creditBalanceOf` returns the signed value.
contract TrokenAyni is IERC20, IERC20Metadata {
    string public constant name = "Gaia TROKEN-AYNI";
    string public constant symbol = "TROKEN";
    uint8 public constant decimals = 18;

    /// @notice Onboarding credit line for new members (33 units).
    uint256 public constant ONBOARDING_CREDIT = 33 ether;
    /// @notice Hard cap on any member's total credit line.
    uint256 public constant MAX_CREDIT_LINE = 100_000 ether;
    /// @notice Clearing cycle length (interest-free period).
    uint256 public constant CLEARING_CYCLE = 365 days;

    StewardRegistry public immutable stewards;

    /// @dev signed net position: positive = surplus, negative = credit used.
    mapping(address => int256) private _net;
    /// @notice credit limit per member (max negative balance magnitude).
    mapping(address => uint256) public creditLine;
    /// @notice start of the member's current clearing cycle.
    mapping(address => uint256) public cycleStartedAt;
    /// @notice negative balances written off into the surplus pool.
    uint256 public defaultedTotal;

    event CreditLineSet(address indexed member, uint256 limit);
    event TransferSigned(address indexed from, address indexed to, uint256 amount);
    event Cleared(address indexed member, uint256 deficit, uint256 cycleStart);

    error ZeroAmount();
    error CreditLimitExceeded(int256 balance, int256 needed, uint256 limit);
    error CapExceeded(uint256 limit, uint256 cap);
    error CycleNotMature(uint256 startedAt, uint256 cycleEnd);

    constructor(StewardRegistry stewards_) {
        stewards = stewards_;
    }

    // ---- views -----------------------------------------------------------

    function totalSupply() external pure override returns (uint256) {
        return 0; // net mutual credit always sums to zero
    }

    /// @notice Signed net position: positive surplus, negative credit drawn.
    function creditBalanceOf(address account) public view returns (int256) {
        return _net[account];
    }

    /// @notice Positive spendable balance (credit headroom included via
    ///         `creditBalanceOf` + `creditLine`).
    function balanceOf(address account) external view override returns (uint256) {
        int256 n = _net[account];
        return n > 0 ? uint256(n) : 0;
    }

    /// @notice Spendable amount: surplus plus remaining credit headroom.
    function spendableOf(address account) external view returns (uint256) {
        return uint256(_net[account] + int256(creditLine[account]));
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0; // mutual credit is not delegated
    }

    // ---- member operations ------------------------------------------------

    /// @notice Open the member's account with the onboarding credit line.
    function openAccount() external {
        if (creditLine[msg.sender] == 0) {
            creditLine[msg.sender] = ONBOARDING_CREDIT;
            cycleStartedAt[msg.sender] = block.timestamp;
            emit CreditLineSet(msg.sender, ONBOARDING_CREDIT);
        }
    }

    /// @notice Extend a member's credit line (steward quorum op
    ///         "TROKEN_CREDIT", member, newLimit). Capped at MAX_CREDIT_LINE.
    function setCreditLine(address member, uint256 newLimit) external {
        if (newLimit > MAX_CREDIT_LINE) revert CapExceeded(newLimit, MAX_CREDIT_LINE);
        stewards.consume(keccak256(abi.encode("TROKEN_CREDIT", member, newLimit)));
        creditLine[member] = newLimit;
        emit CreditLineSet(member, newLimit);
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transferSigned(msg.sender, to, amount);
        return true;
    }

    function approve(address, uint256) external pure override returns (bool) {
        revert("mutual credit: use transfer");
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        revert("mutual credit: no allowance");
    }

    /// @notice Close the member's clearing cycle; deficit marks to the surplus
    ///         pool per the coverage rule (tracked via `defaultedTotal`).
    function clearCycle(address member) external {
        uint256 cycleEnd = cycleStartedAt[member] + CLEARING_CYCLE;
        if (block.timestamp < cycleEnd) revert CycleNotMature(cycleStartedAt[member], cycleEnd);
        int256 n = _net[member];
        if (n < 0) defaultedTotal += uint256(-n);
        emit Cleared(member, n < 0 ? uint256(-n) : 0, cycleStartedAt[member]);
        cycleStartedAt[member] = block.timestamp;
    }

    function _transferSigned(address from, address to, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();
        int256 next = _net[from] - int256(amount);
        if (next < -int256(creditLine[from])) {
            revert CreditLimitExceeded(_net[from], next, creditLine[from]);
        }
        _net[from] = next;
        _net[to] += int256(amount);
        emit Transfer(from, to, amount);
        emit TransferSigned(from, to, amount);
    }
}
