// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @title GaiaUsd (GAIAUSD)
/// @notice Dimension-1 high-velocity fiat bridge: backed 1:1 by fiat reserves
///         held by the custodian foundation. Carries a 1% monthly demurrage
///         ("oxidation") on idle balances; oxidized value is recaptured by the
///         Commons Treasury for ecosystem regeneration. Decay is applied
///         lazily: `balanceOf` reflects pending decay; `settle` checkpoints it.
contract GaiaUsd is ERC20 {
    uint256 public constant MONTH = 30 days;
    /// @notice 1% monthly decay expressed in basis points.
    uint256 public constant DECAY_BPS_PER_MONTH = 100;
    uint256 public constant BPS = 10_000;
    /// @notice Compounding is resolved month-by-month; cap bounds the loop.
    uint256 public constant MAX_COMPOUND_MONTHS = 240;

    StewardRegistry public immutable stewards;
    address public treasury;

    /// @dev per-account last oxidation checkpoint.
    mapping(address => uint256) public lastSettled;
    /// @dev true while inside a settle-triggered update (prevents recursion).
    bool private _settling;

    event BackedMint(address indexed to, uint256 amount, bytes32 indexed reserveRef);
    event Oxidized(address indexed account, uint256 decayed, uint256 months);
    event TreasurySet(address treasury);

    error ZeroAmount();
    error Unauthorized();
    error ZeroAddress();

    constructor(StewardRegistry stewards_, address treasury_) ERC20("Gaia USD", "GAIAUSD") {
        if (treasury_ == address(0)) revert ZeroAddress();
        stewards = stewards_;
        treasury = treasury_;
        emit TreasurySet(treasury_);
    }

    function setTreasury(address t) external {
        if (msg.sender != stewards.multisig()) revert Unauthorized();
        if (t == address(0)) revert ZeroAddress();
        treasury = t;
        emit TreasurySet(t);
    }

    /// @notice Mint against a verified 1:1 fiat reserve deposit.
    function mintBacked(address to, uint256 amount, bytes32 reserveRef) external {
        if (amount == 0) revert ZeroAmount();
        stewards.consume(keccak256(abi.encode("GAIAUSD_MINT", to, amount, reserveRef)));
        _settle(to);
        _mint(to, amount);
        emit BackedMint(to, amount, reserveRef);
    }

    /// @notice Redeem to fiat through the custodian; burns the bridge token.
    function redeem(uint256 amount) external {
        _settle(msg.sender);
        if (amount == 0 || balanceOf(msg.sender) < amount) revert ZeroAmount();
        _burn(msg.sender, amount);
    }

    /// @notice Checkpoint an account's pending oxidation into the treasury.
    function settle(address account) public {
        uint256 months_ = _monthsIdle(account);
        lastSettled[account] = block.timestamp;
        if (months_ == 0) return;
        uint256 bal = super.balanceOf(account);
        uint256 decayed = bal - _decayed(bal, months_);
        if (decayed == 0) return;
        _settling = true;
        _burn(account, decayed);
        _mint(treasury, decayed);
        _settling = false;
        emit Oxidized(account, decayed, months_);
    }

    /// @notice Balance including pending (not-yet-settled) oxidation.
    function balanceOf(address account) public view override returns (uint256) {
        return _decayed(super.balanceOf(account), _monthsIdle(account));
    }

    function _update(address from, address to, uint256 value) internal override {
        if (!_settling && from != address(0)) _settle(from);
        if (!_settling && to != address(0)) _settle(to);
        super._update(from, to, value);
    }

    function _settle(address account) internal {
        uint256 months_ = _monthsIdle(account);
        if (lastSettled[account] == 0) {
            lastSettled[account] = block.timestamp;
            return;
        }
        lastSettled[account] = block.timestamp;
        if (months_ == 0) return;
        uint256 bal = super.balanceOf(account);
        uint256 decayed = bal - _decayed(bal, months_);
        if (decayed == 0) return;
        _settling = true;
        _burn(account, decayed);
        _mint(treasury, decayed);
        _settling = false;
        emit Oxidized(account, decayed, months_);
    }

    function _monthsIdle(address account) internal view returns (uint256) {
        uint256 last = lastSettled[account];
        if (last == 0 || block.timestamp <= last) return 0;
        return (block.timestamp - last) / MONTH;
    }

    function _decayed(uint256 bal, uint256 months_) internal pure returns (uint256 kept) {
        kept = bal;
        uint256 n = months_ > MAX_COMPOUND_MONTHS ? MAX_COMPOUND_MONTHS : months_;
        for (uint256 i; i < n; ++i) {
            kept = (kept * (BPS - DECAY_BPS_PER_MONTH)) / BPS;
            if (kept == 0) break;
        }
    }
}
