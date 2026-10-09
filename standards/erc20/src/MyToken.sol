// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./IERC20.sol";

// Errores personalizados
error InvalidAddress();
error InsufficientBalance(uint256 available, uint256 required);
error InsufficientAllowance(uint256 available, uint256 required);
error CapExceeded(uint256 requested, uint256 available);
error Unauthorized(address caller);
error EnforcedPause();
error ExpectedPause();
error InvalidSignature();
error PermitExpired(uint256 deadline);


// Eventos
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
event MinterUpdated(address indexed account, bool authorized);
event Paused(address indexed account);
event Unpaused(address indexed account);


contract MyToken is IERC20 {

    /* 1. Metadatos del token */
    string private constant _NAME = "My Token";
    string private constant _SYMBOL = "MTK";
    uint8 private constant _DECIMALS  = 18;
    uint256 private constant _UNIT = 10 ** uint256(_DECIMALS);
    uint256 public constant CAP = 2000 * _UNIT;


    // Constantes para la funcion Permit
    // Define el dominio EIP-712, que vincula la firma al contrato y a la red
    bytes32 private constant _DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"); 

    // Define los campos que se firman en un permiso
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // Identifica la versión del dominio como "1"
    bytes32 private constant _VERSION_HASH = keccak256("1");


    /* 2. Variables de estado */
    // Suministro y balances
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    // Autorizaciones ERC-20
    mapping(address => mapping(address => uint256)) private _allowances;

    // Control de acceso
    address private _owner;
    mapping(address => bool) private _minters;

    // Mecanismo de pausado
    bool private _paused;

    // Contador de Nonces para evitar reutilización de firmas
    mapping(address => uint256) public nonces;


    /* 3. Constructor */
    constructor(uint256 initialSupply) {
         uint256 maxWholeTokens = CAP / _UNIT;

        if (initialSupply > maxWholeTokens) {
            revert CapExceeded(initialSupply, maxWholeTokens);
        }

        uint256 supply = initialSupply * _UNIT;

        _owner = msg.sender;
        _minters[msg.sender] = true;

        _totalSupply = supply;
        _balances[msg.sender] = supply;

        emit OwnershipTransferred(address(0), msg.sender);
        emit MinterUpdated(msg.sender, true);
        emit Transfer(address(0), msg.sender, supply);
    }


    /* 4. Modifiers */
    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyMinter() {
        if (!_minters[msg.sender]) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier whenNotPaused() {
        if (_paused) {
            revert EnforcedPause();
        }
        _;
    }


    /* 5. Funciones Metadatos */
    function name() external pure returns (string memory) {
        return _NAME;
    }

    function symbol() external pure returns (string memory) {
        return _SYMBOL;
    }

    function decimals() external pure returns (uint8) {
        return _DECIMALS ;
    }


    /* 6. Funciones ERC-20 */
    // Consulta del suministro total
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    // Consulta del balance de una dirección
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    // Consulta la autorización disponible entre dos direcciones.
    function allowance(address tokenOwner, address spender) external view override returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    // Autoriza a una dirección a gastar tokens en nombre del usuario.
    function approve(address spender, uint256 value) external override returns (bool) {
        if (spender == address(0)) {
            revert InvalidAddress();
        }

        _allowances[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    // Transfiere tokens desde el balance del usuario que llama.
    function transfer(address to, uint256 value) external override whenNotPaused returns (bool) {
        if (to == address(0)) {
            revert InvalidAddress();
        }

        if (_balances[msg.sender] < value) {
            revert InsufficientBalance(_balances[msg.sender], value);
        }

        _balances[msg.sender] -= value;
        _balances[to] += value;

        emit Transfer(msg.sender, to, value);

        return true;
    }

    // Transfiere tokens desde una cuenta utilizando una autorización.
    function transferFrom( address from, address to, uint256 value) external override whenNotPaused returns (bool) {
        if (from == address(0) || to == address(0)) {
            revert InvalidAddress();
        }

        if (_balances[from] < value) {
            revert InsufficientBalance(_balances[from], value);
        }

        if (_allowances[from][msg.sender] < value) {
            revert InsufficientAllowance(_allowances[from][msg.sender], value);
        }

        _allowances[from][msg.sender] -= value;

        _balances[from] -= value;
        _balances[to] += value;

        emit Approval(from, msg.sender, _allowances[from][msg.sender]);
        emit Transfer(from, to, value);

        return true;
    }


    /* 7. Creación y destrucción de tokens */
    function mint(address to, uint256 amount) external onlyMinter whenNotPaused {
        if (to == address(0)) {
            revert InvalidAddress();
        }

        uint256 available = CAP - _totalSupply;

        if (amount > available) {
            revert CapExceeded(amount, available);
        }

        _totalSupply += amount;
        _balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external whenNotPaused {
        if (_balances[msg.sender] < amount) {
            revert InsufficientBalance(_balances[msg.sender], amount);
        }

        _balances[msg.sender] -= amount;
        _totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
    }


    /* 8. Gestión de permisos */
    function owner() external view returns (address) {
        return _owner;
    }
    
    function isMinter(address account) external view returns (bool) {
        return _minters[account];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidAddress();
        }

        address previousOwner = _owner;
        _owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function grantMinter(address account) external onlyOwner {
        if (account == address(0)) {
            revert InvalidAddress();
        }

        _minters[account] = true;
        emit MinterUpdated(account, true);
    }

    function revokeMinter(address account) external onlyOwner {
        if (account == address(0)) {
            revert InvalidAddress();
        }

        _minters[account] = false;
        emit MinterUpdated(account, false);
    }


    /* 9. Gestion de pausado */
    function paused() external view returns (bool) {
        return _paused;
    }

    function pause() external onlyOwner {
        if (_paused) {
            revert EnforcedPause();
        }

        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!_paused) {
            revert ExpectedPause();
        }

        _paused = false;
        emit Unpaused(msg.sender);
    }


    /* 10. Permit (EIP-2612) */
    /// @notice Devuelve el separador de dominio EIP-712.
    /// @dev Vincula las firmas al nombre, versión, red y dirección del contrato.
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                _DOMAIN_TYPEHASH,
                keccak256(bytes(_NAME)),
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    /// @dev Construye el digest EIP-712 que debe firmar el propietario.
    function _hashPermit( address tokenOwner, address spender, uint256 value, uint256 nonce, uint256 deadline) internal view returns (bytes32) {
        
        // Hash de los datos del permiso según la estructura EIP-2612.
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                tokenOwner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        // Digest final: prefijo EIP-712 + dominio + hash de la estructura.
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                structHash
            )
        );
    }

    /// @notice Establece una autorización ERC-20 mediante una firma EIP-712.
    /// @dev La firma debe pertenecer a tokenOwner y utilizar su nonce actual.
    function permit(address tokenOwner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        // Comprobar que el permiso no ha caducado.
        if (block.timestamp > deadline) {
            revert PermitExpired(deadline);
        }

        // Las direcciones del propietario y del destinatario deben ser válidas.
        if (tokenOwner == address(0) || spender == address(0)) {
            revert InvalidAddress();
        }

        // Rechazar firmas con s no canónico o un valor v no admitido.
        if (uint256(s) > 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0 || (v != 27 && v != 28)) {
            revert InvalidSignature();
        }

        // Obtener el nonce actual para impedir reutilizar la firma.
        uint256 currentNonce = nonces[tokenOwner];

        // Calcular el digest EIP-712 que debe haberse firmado.
        bytes32 digest = _hashPermit(tokenOwner, spender, value, currentNonce, deadline);

        // Recuperar direccion del firmante
        address signer = ecrecover(digest, v, r, s);

        if (signer == address(0) || signer != tokenOwner) {
            revert InvalidSignature();
        }

        // Consumir el nonce y actualizar la autorización.
        nonces[tokenOwner] = currentNonce + 1;
        _allowances[tokenOwner][spender] = value;

        emit Approval(tokenOwner, spender, value);
    }
}