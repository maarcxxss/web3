// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {
    MyToken,
    InsufficientBalance,
    InvalidAddress,
    InsufficientAllowance,
    CapExceeded,
    Unauthorized,
    EnforcedPause,
    ExpectedPause,
    InvalidSignature,
    PermitExpired,
    OwnershipTransferred,
    MinterUpdated,
    Paused,
    Unpaused
} from 

"../src/MyToken.sol";

import {IERC20} from "../src/IERC20.sol";

contract MyTokenTest is Test {
    // =============================================================
    // CONSTANTS
    // =============================================================

    uint256 private constant UNIT = 10 ** 18;
    uint256 private constant INITIAL_SUPPLY = 1000 * UNIT;

    // =============================================================
    // TEST ACCOUNTS
    // =============================================================

    address private owner = address(1);
    address private account2 = address(2);
    address private account3 = address(3);

    // =============================================================
    // CONTRACT UNDER TEST
    // =============================================================

    MyToken public token;

    // =============================================================
    // SETUP
    // =============================================================

    function setUp() public {
        vm.prank(owner);
        token = new MyToken(1000);
    }

    // =============================================================
    // 01. INITIAL STATE
    // =============================================================

    function test_InitialState() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function test_Name() public view {
        assertEq(token.name(), "MyToken");
    }

    function test_Symbol() public view {
        assertEq(token.symbol(), "MTK");
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_Owner() public view {
        assertEq(token.owner(), owner);
    }

    function test_IsMinter() public view {
        assertTrue(token.isMinter(owner));
        assertFalse(token.isMinter(account2));
    }

    function test_Paused() public view {
        assertFalse(token.paused());
    }

    function test_ConstructorExceedsCap() public {
        uint256 maxWholeTokens = token.CAP() / (10 ** 18);
        uint256 invalidSupply = maxWholeTokens + 1;

        vm.expectRevert(abi.encodeWithSelector(CapExceeded.selector, invalidSupply, maxWholeTokens));

        new MyToken(invalidSupply);
    }

    // =============================================================
    // 02. TRANSFER
    // =============================================================

    /* --- Successful transfers --- */
    function test_Transfer() public {
        uint256 amount = 250 * UNIT;

        vm.prank(owner);
        token.transfer(account2, amount);

        assertEq(token.balanceOf(owner), 750 * UNIT);
        assertEq(token.balanceOf(account2), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_TransferZeroAmount() public {
        uint256 initialOwnerBalance = token.balanceOf(owner);
        uint256 initialRecipientBalance = token.balanceOf(account2);

        vm.prank(owner);
        bool success = token.transfer(account2, 0);

        assertTrue(success);
        assertEq(token.balanceOf(owner), initialOwnerBalance);
        assertEq(token.balanceOf(account2), initialRecipientBalance);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_TransferExactBalance() public {
        uint256 amount = token.balanceOf(owner);

        vm.prank(owner);
        bool success = token.transfer(account2, amount);

        assertTrue(success);
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(account2), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    /* --- Reverts --- */
    function test_TransferInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY;

        vm.prank(owner);
        token.transfer(account2, 250 * UNIT); // Transferimos 250 (quedan 1000-250 = 750)

        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, 750 * UNIT, amount));

        vm.prank(owner);
        token.transfer(account2, amount); // Transferimos 1000 (y quedaban 750)
    }

    function test_TransferZeroAddress() public {
        uint256 amount = 100 * UNIT;

        vm.expectRevert(InvalidAddress.selector);

        vm.prank(owner);
        token.transfer(address(0), amount);
    }

    function test_TransferWhenPaused() public {
        vm.prank(owner);
        token.pause();

        vm.expectRevert(EnforcedPause.selector);

        vm.prank(owner);
        token.transfer(account2, 100 * UNIT);
    }

    /* --- Events --- */
    function test_TransferEvent() public {
        uint256 amount = 250 * UNIT;

        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(owner, account2, amount);

        vm.prank(owner);
        token.transfer(account2, amount);
    }

    // =============================================================
    // 03. APPROVE
    // =============================================================

    /* --- Successful approvals --- */
    function test_Approve() public {
        uint256 amount = 300 * UNIT;

        vm.prank(owner);
        token.approve(account2, amount);

        assertEq(token.allowance(owner, account2), amount);
    }

    function test_ApproveReplacesAllowance() public {
        uint256 firstAmount = 300 * UNIT;
        uint256 secondAmount = 100 * UNIT;

        vm.startPrank(owner);

        token.approve(account2, firstAmount);
        assertEq(token.allowance(owner, account2), firstAmount);

        token.approve(account2, secondAmount);
        assertEq(token.allowance(owner, account2), secondAmount);

        vm.stopPrank();
    }

    function test_ApproveZeroAmount() public {
        vm.prank(owner);
        token.approve(account2, 300 * UNIT);

        vm.prank(owner);
        bool success = token.approve(account2, 0);

        assertTrue(success);
        assertEq(token.allowance(owner, account2), 0);
    }

    function test_ApproveWhenPaused() public {
        vm.prank(owner);
        token.pause();

        vm.prank(owner);
        bool success = token.approve(account2, 100 * UNIT);

        assertTrue(success);
        assertEq(token.allowance(owner, account2), 100 * UNIT);
    }

    /* --- Reverts --- */
    function test_ApproveZeroAddress() public {
        uint256 amount = 100 * UNIT;

        vm.expectRevert(InvalidAddress.selector);

        vm.prank(owner);
        token.approve(address(0), amount);
    }

    /* --- Events --- */
    function test_ApprovalEvent() public {
        uint256 amount = 300 * UNIT;

        vm.expectEmit(true, true, false, true);
        emit IERC20.Approval(owner, account2, amount);

        vm.prank(owner);
        token.approve(account2, amount);
    }

    // =============================================================
    // 04. TRANSFER FROM
    // =============================================================

    /* --- Successful transfers --- */
    function test_TransferFrom() public {
        uint256 allowanceAmount = 300 * UNIT;
        uint256 transferAmount = 200 * UNIT;

        vm.prank(owner);
        token.approve(account2, allowanceAmount);

        vm.prank(account2);
        token.transferFrom(owner, account3, transferAmount);

        assertEq(token.balanceOf(owner), 800 * UNIT);
        assertEq(token.balanceOf(account3), transferAmount);
        assertEq(token.allowance(owner, account2), 100 * UNIT);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_TransferFromZeroAmount() public {
        uint256 allowanceAmount = 300 * UNIT;

        vm.prank(owner);
        token.approve(account2, allowanceAmount);

        vm.prank(account2);
        bool success = token.transferFrom(owner, account3, 0);

        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.balanceOf(account3), 0);
        assertEq(token.allowance(owner, account2), allowanceAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    /* --- Reverts --- */
    function test_TransferFromInsufficientAllowance() public {
        uint256 allowanceAmount = 100 * UNIT;
        uint256 transferAmount = 150 * UNIT;

        vm.prank(owner);
        token.approve(account2, allowanceAmount);

        vm.expectRevert(abi.encodeWithSelector(InsufficientAllowance.selector, allowanceAmount, transferAmount));

        vm.prank(account2);
        token.transferFrom(owner, account3, transferAmount);
    }

    function test_TransferFromInsufficientBalance() public {
        uint256 allowanceAmount = 300 * UNIT;
        uint256 transferAmount = 150 * UNIT;

        vm.prank(owner);
        token.approve(account2, allowanceAmount);

        vm.prank(owner);
        token.transfer(account2, 900 * UNIT);

        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, 100 * UNIT, transferAmount));

        vm.prank(account2);
        token.transferFrom(owner, account3, transferAmount);
    }

    function test_TransferFromZeroAddress() public {
        uint256 allowanceAmount = 300 * UNIT;
        uint256 transferAmount = 200 * UNIT;

        vm.prank(owner);
        token.approve(account2, allowanceAmount);

        vm.expectRevert(InvalidAddress.selector);

        vm.prank(account2);
        token.transferFrom(owner, address(0), transferAmount);
    }

    function test_TransferFromWhenPaused() public {
        vm.prank(owner);
        token.approve(account2, 100 * UNIT);

        vm.prank(owner);
        token.pause();

        vm.expectRevert(EnforcedPause.selector);

        vm.prank(account2);
        token.transferFrom(owner, account3, 50 * UNIT);
    }

    /* --- Events --- */
    function test_TransferFromEvents() public {
        uint256 allowanceAmount = 300 * UNIT;
        uint256 transferAmount = 200 * UNIT;

        vm.prank(owner);
        token.approve(account2, allowanceAmount);

        vm.expectEmit(true, true, false, true);
        emit IERC20.Approval(owner, account2, 100 * UNIT);

        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(owner, account3, transferAmount);

        vm.prank(account2);
        token.transferFrom(owner, account3, transferAmount);
    }

    // =============================================================
    // 05. MINT
    // =============================================================

    /* --- Successful minting --- */
    function test_Mint() public {
        uint256 amount = 100 * UNIT;

        vm.prank(owner);
        token.mint(account2, amount);

        assertEq(token.balanceOf(account2), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
    }

    function test_MintExactCap() public {
        uint256 remainingCapacity = token.CAP() - token.totalSupply();

        vm.prank(owner);
        token.mint(account2, remainingCapacity);

        assertEq(token.totalSupply(), token.CAP());
        assertEq(token.balanceOf(account2), remainingCapacity);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    /* --- Reverts --- */
    function test_MintExceedsCap() public {
        uint256 available = token.CAP() - INITIAL_SUPPLY;
        uint256 amount = available + 1;

        vm.expectRevert(abi.encodeWithSelector(CapExceeded.selector, amount, available));

        vm.prank(owner);
        token.mint(account2, amount);
    }

    function test_MintUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, account2));

        vm.prank(account2);
        token.mint(account3, UNIT);
    }

    function test_MintZeroAddress() public {
        vm.expectRevert(InvalidAddress.selector);

        vm.prank(owner);
        token.mint(address(0), UNIT);
    }

    function test_MintWhenPaused() public {
        vm.prank(owner);
        token.pause();

        vm.expectRevert(EnforcedPause.selector);

        vm.prank(owner);
        token.mint(account2, 100 * UNIT);
    }

    /* --- Events --- */
    function test_MintEmitsTransferEvent() public {
        uint256 amount = 100 * UNIT;

        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(address(0), account2, amount);

        vm.prank(owner);
        token.mint(account2, amount);
    }

    // =============================================================
    // 06. BURN
    // =============================================================

    /* --- Successful burning --- */
    function test_Burn() public {
        uint256 amount = 100 * UNIT;

        vm.prank(owner);
        token.burn(amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function test_BurnZeroAmount() public {
        uint256 initialBalance = token.balanceOf(owner);
        uint256 initialSupply = token.totalSupply();

        vm.prank(owner);
        token.burn(0);

        assertEq(token.balanceOf(owner), initialBalance);
        assertEq(token.totalSupply(), initialSupply);
    }

    function test_BurnExactBalance() public {
        uint256 amount = token.balanceOf(owner);

        vm.prank(owner);
        token.burn(amount);

        assertEq(token.balanceOf(owner), 0);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    /* --- Reverts --- */
    function test_BurnInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;

        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, INITIAL_SUPPLY, amount));

        vm.prank(owner);
        token.burn(amount);
    }

    function test_BurnWhenPaused() public {
        vm.prank(owner);
        token.pause();

        vm.expectRevert(EnforcedPause.selector);

        vm.prank(owner);
        token.burn(100 * UNIT);
    }

    /* --- Events --- */
    function test_BurnEmitsTransferEvent() public {
        uint256 amount = 100 * UNIT;

        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(owner, address(0), amount);

        vm.prank(owner);
        token.burn(amount);
    }

    // =============================================================
    // 07. ACCESS CONTROL
    // =============================================================

    /* --- Successful operations --- */
    function test_TransferOwnership() public {
        vm.prank(owner);
        token.transferOwnership(account2);

        assertEq(token.owner(), account2);
    }

    function test_GrantMinter() public {
        vm.prank(owner);
        token.grantMinter(account2);

        assertTrue(token.isMinter(account2));
    }

    function test_RevokeMinter() public {
        vm.prank(owner);
        token.grantMinter(account2);

        vm.prank(owner);
        token.revokeMinter(account2);

        assertFalse(token.isMinter(account2));
    }

    /* --- Reverts --- */
    function test_TransferOwnershipUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, account2));

        vm.prank(account2);
        token.transferOwnership(account3);
    }

    function test_TransferOwnershipZeroAddress() public {
        vm.expectRevert(InvalidAddress.selector);

        vm.prank(owner);
        token.transferOwnership(address(0));
    }

    function test_GrantMinterUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, account2));

        vm.prank(account2);
        token.grantMinter(account3);
    }

    function test_GrantMinterZeroAddress() public {
        vm.expectRevert(InvalidAddress.selector);

        vm.prank(owner);
        token.grantMinter(address(0));
    }

    function test_RevokeMinterUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, account2));

        vm.prank(account2);
        token.revokeMinter(owner);
    }

    function test_RevokeMinterZeroAddress() public {
        vm.expectRevert(InvalidAddress.selector);

        vm.prank(owner);
        token.revokeMinter(address(0));
    }

    /* --- Events --- */
    function test_TransferOwnershipEmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, account2);

        vm.prank(owner);
        token.transferOwnership(account2);
    }

    function test_GrantMinterEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit MinterUpdated(account2, true);

        vm.prank(owner);
        token.grantMinter(account2);
    }

    function test_RevokeMinterEmitsEvent() public {
        vm.prank(owner);
        token.grantMinter(account2);

        vm.expectEmit(true, false, false, true);
        emit MinterUpdated(account2, false);

        vm.prank(owner);
        token.revokeMinter(account2);
    }

    // =============================================================
    // 08. PAUSE/ UNPAUSE
    // =============================================================

    /* --- Successful operations --- */
    function test_Pause() public {
        vm.prank(owner);
        token.pause();

        assertTrue(token.paused());
    }

    function test_Unpause() public {
        vm.prank(owner);
        token.pause();

        vm.prank(owner);
        token.unpause();

        assertFalse(token.paused());
    }

    /* --- Reverts --- */
    function test_PauseUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, account2));

        vm.prank(account2);
        token.pause();
    }

    function test_PauseAlreadyPaused() public {
        vm.prank(owner);
        token.pause();

        vm.expectRevert(EnforcedPause.selector);

        vm.prank(owner);
        token.pause();
    }

    function test_UnpauseUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, account2));

        vm.prank(account2);
        token.unpause();
    }

    function test_UnpauseWhenNotPaused() public {
        vm.expectRevert(ExpectedPause.selector);

        vm.prank(owner);
        token.unpause();
    }

    /* --- Events --- */
    function test_PauseEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Paused(owner);

        vm.prank(owner);
        token.pause();
    }

    function test_UnpauseEmitsEvent() public {
        vm.prank(owner);
        token.pause();

        vm.expectEmit(true, false, false, true);
        emit Unpaused(owner);

        vm.prank(owner);
        token.unpause();
    }

    // =============================================================
    // 09. PERMIT
    // =============================================================

    /* --- Successful permit --- */
    function test_PermitValidSignature() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, permitOwner, account2, value, token.nonces(permitOwner), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(permitOwner, account2, value);

        token.permit(permitOwner, account2, value, deadline, v, r, s);

        assertEq(token.allowance(permitOwner, account2), value);
        assertEq(token.nonces(permitOwner), 1);
    }

    function test_PermitWhenPaused() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, permitOwner, account2, value, token.nonces(permitOwner), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.prank(owner);
        token.pause();

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(permitOwner, account2, value);

        token.permit(permitOwner, account2, value, deadline, v, r, s);

        assertEq(token.allowance(permitOwner, account2), value);
        assertEq(token.nonces(permitOwner), 1);
    }

    function test_PermitAtExactDeadline() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, permitOwner, account2, value, token.nonces(permitOwner), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.warp(deadline);

        token.permit(permitOwner, account2, value, deadline, v, r, s);

        assertEq(token.allowance(permitOwner, account2), value);
        assertEq(token.nonces(permitOwner), 1);
    }

    /* --- Reverts --- */
    function test_PermitInvalidSigner() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);
        address fakeOwner = account3;
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, signer, account2, value, token.nonces(signer), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(InvalidSignature.selector);
        token.permit(fakeOwner, account2, value, deadline, v, r, s);

        assertEq(token.allowance(fakeOwner, account2), 0);
        assertEq(token.nonces(fakeOwner), 0);
    }

    function test_PermitExpiredDeadline() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, permitOwner, account2, value, token.nonces(permitOwner), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.warp(deadline + 1);

        vm.expectRevert(abi.encodeWithSelector(PermitExpired.selector, deadline));
        token.permit(permitOwner, account2, value, deadline, v, r, s);

        assertEq(token.allowance(permitOwner, account2), 0);
        assertEq(token.nonces(permitOwner), 0);
    }

    function test_PermitReusedSignature() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, permitOwner, account2, value, token.nonces(permitOwner), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.permit(permitOwner, account2, value, deadline, v, r, s);

        assertEq(token.nonces(permitOwner), 1);
        assertEq(token.allowance(permitOwner, account2), value);

        vm.expectRevert(InvalidSignature.selector);
        token.permit(permitOwner, account2, value, deadline, v, r, s);

        assertEq(token.nonces(permitOwner), 1);
        assertEq(token.allowance(permitOwner, account2), value);
    }

    function test_PermitModifiedValue() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 signedValue = 100 * UNIT;
        uint256 modifiedValue = 200 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash = keccak256(
            abi.encode(permitTypeHash, permitOwner, account2, signedValue, token.nonces(permitOwner), deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(InvalidSignature.selector);
        token.permit(permitOwner, account2, modifiedValue, deadline, v, r, s);

        assertEq(token.allowance(permitOwner, account2), 0);
        assertEq(token.nonces(permitOwner), 0);
    }

    function test_PermitHighS() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, permitOwner, account2, value, token.nonces(permitOwner), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        uint256 secp256k1N = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;
        bytes32 highS = bytes32(secp256k1N - uint256(s));

        uint8 highV = v == 27 ? 28 : 27;

        vm.expectRevert(InvalidSignature.selector);
        token.permit(permitOwner, account2, value, deadline, highV, r, highS);

        assertEq(token.allowance(permitOwner, account2), 0);
        assertEq(token.nonces(permitOwner), 0);
    }

    function test_PermitInvalidV() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, permitOwner, account2, value, token.nonces(permitOwner), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(InvalidSignature.selector);
        token.permit(permitOwner, account2, value, deadline, 29, r, s);

        assertEq(token.allowance(permitOwner, account2), 0);
        assertEq(token.nonces(permitOwner), 0);
    }

    function test_PermitZeroOwner() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, permitOwner, account2, value, token.nonces(permitOwner), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(InvalidAddress.selector);
        token.permit(address(0), account2, value, deadline, v, r, s);

        assertEq(token.allowance(address(0), account2), 0);
        assertEq(token.nonces(address(0)), 0);
    }

    function test_PermitZeroSpender() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 value = 100 * UNIT;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypeHash, permitOwner, address(0), value, token.nonces(permitOwner), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(InvalidAddress.selector);
        token.permit(permitOwner, address(0), value, deadline, v, r, s);

        assertEq(token.allowance(permitOwner, address(0)), 0);
        assertEq(token.nonces(permitOwner), 0);
    }
}
