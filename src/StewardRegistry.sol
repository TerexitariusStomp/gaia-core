// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

/// @title StewardRegistry
/// @notice Registry of Treasury Stewards who passed the Certification of Trust.
/// @dev Governance and minting authority is granted only to certified Stewards
///      (never by token holdings). Privileged operations require at least
///      `requiredApprovals` distinct steward approvals for the same operation
///      hash, consumed on execution — mirroring the 3-of-N multi-sig mandate.
contract StewardRegistry {
    /// @notice Minimum distinct steward approvals required per privileged op.
    uint256 public constant REQUIRED_APPROVALS = 3;

    /// @notice The multisig (Safe) that administers the steward set itself.
    address public multisig;

    /// @notice Certified Treasury Stewards.
    mapping(address => bool) public isSteward;
    uint256 public stewardCount;

    /// @notice approval tally and voter set per operation hash.
    mapping(bytes32 => uint256) public approvals;
    mapping(bytes32 => mapping(address => bool)) public hasApproved;

    event StewardAdded(address indexed steward);
    event StewardRevoked(address indexed steward);
    event Approved(bytes32 indexed op, address indexed steward, uint256 count);
    event Consumed(bytes32 indexed op);

    error NotMultisig();
    error NotSteward();
    error AlreadyApproved();
    error NotApproved(bytes32 op);
    error ZeroAddress();

    modifier onlyMultisig() {
        if (msg.sender != multisig) revert NotMultisig();
        _;
    }

    constructor(address multisig_) {
        if (multisig_ == address(0)) revert ZeroAddress();
        multisig = multisig_;
    }

    /// @notice Certify a steward (Certification of Trust passed). Multisig-gated.
    function addSteward(address steward) external onlyMultisig {
        if (steward == address(0)) revert ZeroAddress();
        if (isSteward[steward]) return;
        isSteward[steward] = true;
        stewardCount += 1;
        emit StewardAdded(steward);
    }

    /// @notice Revoke a steward's certification. Multisig-gated.
    function revokeSteward(address steward) external onlyMultisig {
        if (!isSteward[steward]) return;
        isSteward[steward] = false;
        stewardCount -= 1;
        emit StewardRevoked(steward);
    }

    /// @notice Steward signals approval for an operation hash.
    /// @param op keccak256(abi.encode(...)) identifying the operation.
    function approve(bytes32 op) external {
        if (!isSteward[msg.sender]) revert NotSteward();
        if (hasApproved[op][msg.sender]) revert AlreadyApproved();
        hasApproved[op][msg.sender] = true;
        uint256 n = ++approvals[op];
        emit Approved(op, msg.sender, n);
    }

    /// @notice True once `op` has at least REQUIRED_APPROVALS distinct approvals.
    function isApproved(bytes32 op) external view returns (bool) {
        return approvals[op] >= REQUIRED_APPROVALS;
    }

    /// @notice Consume an approval quorum for `op`. Called by managed contracts.
    function consume(bytes32 op) external {
        if (approvals[op] < REQUIRED_APPROVALS) revert NotApproved(op);
        approvals[op] = 0;
        emit Consumed(op);
    }

    function setMultisig(address next) external onlyMultisig {
        if (next == address(0)) revert ZeroAddress();
        multisig = next;
    }
}
