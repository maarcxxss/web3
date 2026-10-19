// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../src/IERC20.sol";

/// @dev Test token with configurable transfer results and an optional callback.
contract CoverageERC20 is IERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bool public transferReturns = true;
    bool public transferFromReturns = true;
    bool public bubbleCallbackFailure = true;
    bool public callbackSucceeded;
    address public callbackTarget;
    bytes public callbackData;
    bytes public callbackReturndata;

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function setTransferReturns(bool result) external {
        transferReturns = result;
    }

    function setTransferFromReturns(bool result) external {
        transferFromReturns = result;
    }

    function setCallback(address target, bytes calldata data, bool bubbleFailure) external {
        callbackTarget = target;
        callbackData = data;
        bubbleCallbackFailure = bubbleFailure;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (!transferReturns) return false;
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (!transferFromReturns) return false;

        uint256 approvedAmount = allowance[from][msg.sender];
        require(approvedAmount >= amount, "insufficient allowance");
        allowance[from][msg.sender] = approvedAmount - amount;
        emit Approval(from, msg.sender, allowance[from][msg.sender]);
        _transfer(from, to, amount);

        if (callbackTarget != address(0)) {
            (bool success, bytes memory returndata) = callbackTarget.call(callbackData);
            callbackSucceeded = success;
            callbackReturndata = returndata;
            if (!success && bubbleCallbackFailure) {
                assembly ("memory-safe") {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(to != address(0), "invalid recipient");
        require(balanceOf[from] >= amount, "insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
