// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./IERC20.sol";

contract Staking {
    // =============================================================
    // CUSTOM ERRORS
    // =============================================================

    error InvalidStakingTokenAddress();
    error StakingTokenHasNoCode();
    error InvalidRewardsTokenAddress();
    error RewardsTokenHasNoCode();
    error ReentrantCall();
    error NotOwner();
    error AmountMustBeGreaterThanZero();
    error StakingTokenTransferFailed();
    error RewardsTokenTransferFailed();
    error UnexpectedAmountReceived(uint256 expected, uint256 actual);
    error InsufficientStakedBalance(uint256 available, uint256 requested);
    error RewardPeriodActive(uint256 periodFinish);
    error RewardRateIsZero(uint256 amount, uint256 duration);
    error InsufficientRewardReserve(uint256 actualBalance, uint256 requiredBalance);

    // =============================================================
    // CONSTANTES
    // =============================================================

    // Factor de escala utilizado para calcular las recompensas
    // con precisión decimal, aunque Solidity trabaje con enteros.
    uint256 private constant PRECISION = 1e18;

    // =============================================================
    // EVENTOS
    // =============================================================

    // Se emite cuando un usuario deposita tokens para hacer staking.
    event Staked(address indexed user, uint256 amount);

    // Se emite cuando un usuario retira tokens depositados.
    event Withdrawn(address indexed user, uint256 amount);

    // Se emite cuando un usuario cobra sus recompensas.
    event RewardPaid(address indexed user, uint256 reward);

    // =============================================================
    // VARIABLES DE ESTADO
    // =============================================================

    // -------------------------------------------------------------
    // Control de acceso
    // -------------------------------------------------------------

    // Dirección que puede administrar la financiación de recompensas.
    address public owner;

    // -------------------------------------------------------------
    // Gestión del staking
    // -------------------------------------------------------------

    // Token que los usuarios deben depositar para participar.
    IERC20 public token;

    // Cantidad de tokens depositados por cada usuario.
    mapping(address => uint256) private _stakedBalance;

    // Cantidad total de tokens depositados en el contrato.
    uint256 public totalStaked;

    // -------------------------------------------------------------
    // Gestión de recompensas
    // -------------------------------------------------------------

    // Token utilizado para pagar las recompensas.
    // Puede ser diferente del token utilizado para hacer staking.
    IERC20 public rewardsToken;

    // Cantidad de recompensas distribuidas por segundo.
    uint256 public rewardRate;

    // Último instante hasta el que se ha actualizado la contabilidad.
    uint256 public lastUpdateTime;

    // Acumulador de recompensas por cada unidad de staking,
    // expresado con la precisión definida en PRECISION.
    uint256 public rewardPerTokenStored;

    // Valor del acumulador que ya se ha contabilizado para cada usuario.
    mapping(address => uint256) public userRewardPerTokenPaid;

    // Recompensas acumuladas pendientes de cobrar por cada usuario.
    mapping(address => uint256) public rewards;

    // Reserva contable para cubrir recompensas pendientes y
    // recompensas presupuestadas para el periodo activo.
    uint256 public reservedRewards;

    // Recompensas generadas durante el periodo actual o el último.
    // Se utiliza para calcular el presupuesto que no llegó a generarse.
    uint256 public periodRewardsGenerated;

    // -------------------------------------------------------------
    // Duración y finalización de los periodos de recompensas
    // -------------------------------------------------------------

    // Instante en el que termina el periodo de recompensas.
    uint256 public periodFinish;

    // Duración de cada periodo de distribución: siete días.
    uint256 public rewardsDuration = 7 days;

    // -------------------------------------------------------------
    // Protección frente a reentrancy
    // -------------------------------------------------------------

    // Indica si existe una ejecución protegida en curso.
    bool private _locked;

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    /**
     * @notice Inicializa el sistema de staking.
     * @dev Comprueba que ambas direcciones sean válidas y correspondan
     *      a contratos antes de almacenarlas.
     * @param stakingTokenAddress Dirección del token que se depositará.
     * @param rewardsTokenAddress Dirección del token de recompensas.
     */
    constructor(address stakingTokenAddress, address rewardsTokenAddress) {
        // El token de staking debe tener una dirección válida.
        if (stakingTokenAddress == address(0)) revert InvalidStakingTokenAddress();

        // Evita configurar una dirección sin código de contrato.
        if (stakingTokenAddress.code.length == 0) revert StakingTokenHasNoCode();

        // El token de recompensas también debe ser válido.
        if (rewardsTokenAddress == address(0)) revert InvalidRewardsTokenAddress();

        if (rewardsTokenAddress.code.length == 0) revert RewardsTokenHasNoCode();

        // Convertimos las direcciones a la interfaz IERC20 para
        // poder consultar balances y ejecutar transferencias.
        token = IERC20(stakingTokenAddress);
        rewardsToken = IERC20(rewardsTokenAddress);

        // La cuenta que despliega el contrato será su propietario.
        owner = msg.sender;
    }

    // =============================================================
    // MODIFICADORES
    // =============================================================

    /**
     * @notice Impide ejecutar funciones protegidas de forma reentrante.
     * @dev Bloquea la entrada antes de ejecutar la función y libera
     *      el bloqueo cuando esta termina correctamente.
     */
    modifier nonReentrant() {
        if (_locked) revert ReentrantCall();

        _locked = true;

        _;

        _locked = false;
    }

    /**
     * @notice Restringe la ejecución al propietario del contrato.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();

        _;
    }

    // =============================================================
    // CONSULTAS DE STAKING
    // =============================================================

    /**
     * @notice Devuelve el balance depositado por un usuario.
     * @param user Dirección del usuario consultado.
     * @return Cantidad de tokens que mantiene depositados.
     */
    function stakedBalance(address user) external view returns (uint256) {
        return _stakedBalance[user];
    }

    // =============================================================
    // OPERACIONES DE STAKING
    // =============================================================

    /**
     * @notice Deposita tokens en el contrato para participar en el staking.
     * @dev El usuario debe haber autorizado previamente al contrato
     *      mediante approve. Se comprueba el balance recibido para
     *      rechazar tokens que no transfieran exactamente la cantidad
     *      solicitada.
     * @param amount Cantidad de tokens que se desea depositar.
     */
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountMustBeGreaterThanZero();

        // Actualizamos las recompensas del usuario antes de modificar
        // su balance, para conservar correctamente las acumuladas.
        _updateReward(msg.sender);

        // Guardamos el balance anterior para comprobar la transferencia.
        uint256 balanceBefore = token.balanceOf(address(this));

        // El contrato necesita una autorización previa del usuario.
        bool success = token.transferFrom(msg.sender, address(this), amount);

        if (!success) revert StakingTokenTransferFailed();

        // Comprobamos cuánto ha recibido realmente el contrato.
        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 received = balanceAfter - balanceBefore;

        // Este staking requiere que se reciba exactamente lo solicitado.
        if (received != amount) revert UnexpectedAmountReceived(amount, received);

        // Registramos el depósito del usuario y el total del sistema.
        _stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Retira tokens que el usuario había depositado.
     * @dev Actualiza primero las recompensas y después reduce el
     *      balance contabilizado antes de realizar la transferencia.
     * @param amount Cantidad de tokens que se desea retirar.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountMustBeGreaterThanZero();

        if (_stakedBalance[msg.sender] < amount) {
            revert InsufficientStakedBalance(_stakedBalance[msg.sender], amount);
        }

        // Conservamos las recompensas generadas antes de modificar
        // el balance depositado por el usuario.
        _updateReward(msg.sender);

        // Efectos: actualizamos el estado antes de interactuar
        // externamente con el contrato del token.
        _stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        // Interacción: devolvemos los tokens al usuario.
        bool success = token.transfer(msg.sender, amount);

        if (!success) revert StakingTokenTransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    // =============================================================
    // CÁLCULO DE RECOMPENSAS
    // =============================================================

    /**
     * @notice Devuelve el último instante al que se aplican recompensas.
     * @dev El tiempo actual nunca puede superar el final del periodo.
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Calcula las recompensas acumuladas por unidad de staking.
     * @dev Utiliza PRECISION para reducir la pérdida de precisión
     *      causada por la aritmética entera de Solidity.
     */
    function rewardPerToken() public view returns (uint256) {
        // Si no hay tokens depositados, no se incrementa el acumulador.
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        // Recompensa acumulada:
        // recompensa previa + (tiempo transcurrido * tasa * precisión)
        // dividido entre el total de tokens depositados.
        return
            rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION)
                / totalStaked;
    }

    /**
     * @notice Calcula las recompensas acumuladas de un usuario.
     * @param user Dirección del usuario consultado.
     * @return Recompensas generadas y todavía no cobradas.
     */
    function earned(address user) public view returns (uint256) {
        // Se calcula la participación del usuario en el incremento
        // del acumulador desde su última actualización.
        return (_stakedBalance[user] * (rewardPerToken() - userRewardPerTokenPaid[user])) / PRECISION + rewards[user];
    }

    /**
     * @notice Actualiza la contabilidad global y la de un usuario.
     * @dev Si account es address(0), solo actualiza los datos globales.
     *      Esto permite actualizar un periodo sin modificar la cuenta
     *      de ningún usuario concreto.
     * @param account Usuario cuyas recompensas se quieren actualizar.
     */
    function _updateReward(address account) internal {
        uint256 applicableTime = lastTimeRewardApplicable();

        // Tiempo transcurrido desde la última actualización global.
        uint256 elapsed = applicableTime - lastUpdateTime;

        // Actualizamos el acumulador antes de modificar el timestamp.
        rewardPerTokenStored = rewardPerToken();

        // Solo contabilizamos emisiones generadas cuando existe
        // staking depositado en el sistema.
        if (totalStaked > 0) {
            periodRewardsGenerated += elapsed * rewardRate;
        }

        lastUpdateTime = applicableTime;

        // Si se indica un usuario, consolidamos sus recompensas.
        if (account != address(0)) {
            rewards[account] = earned(account);

            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    // =============================================================
    // FINANCIACIÓN Y CONFIGURACIÓN DE RECOMPENSAS
    // =============================================================

    /**
     * @notice Financia e inicia un nuevo periodo de recompensas.
     * @dev Solo puede ejecutarlo el propietario y no permite iniciar
     *      un periodo mientras el anterior siga activo.
     * @param amount Cantidad de tokens de recompensa que se aportan.
     */
    function fundRewards(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert AmountMustBeGreaterThanZero();

        if (block.timestamp < periodFinish) revert RewardPeriodActive(periodFinish);

        // Actualizamos la contabilidad del periodo anterior.
        _updateReward(address(0));

        // Presupuesto que se había programado para el periodo anterior.
        uint256 previousScheduledRewards = rewardRate * rewardsDuration;

        // Parte del presupuesto anterior que no llegó a generarse.
        uint256 unusedRewards = previousScheduledRewards - periodRewardsGenerated;

        // Conservamos la reserva necesaria para cubrir las recompensas
        // ya generadas que todavía no han sido cobradas.
        uint256 availableReserve = reservedRewards - unusedRewards;

        // Medimos el balance antes de recibir los nuevos fondos.
        uint256 balanceBefore = rewardsToken.balanceOf(address(this));

        bool success = rewardsToken.transferFrom(msg.sender, address(this), amount);

        if (!success) revert RewardsTokenTransferFailed();

        // Comprobamos que se han recibido exactamente los fondos pedidos.
        uint256 balanceAfter = rewardsToken.balanceOf(address(this));

        uint256 received = balanceAfter - balanceBefore;

        if (received != amount) revert UnexpectedAmountReceived(amount, received);

        // Calculamos la tasa de emisión por segundo.
        // La división entera puede dejar un pequeño resto sin programar.
        uint256 newRewardRate = received / rewardsDuration;

        if (newRewardRate == 0) revert RewardRateIsZero(received, rewardsDuration);

        // Presupuesto que realmente se distribuirá durante el periodo.
        uint256 scheduledRewards = newRewardRate * rewardsDuration;

        // El contrato debe conservar fondos suficientes para cubrir
        // la reserva anterior y todas las recompensas programadas.
        uint256 requiredBalance = availableReserve + scheduledRewards;
        if (balanceAfter < requiredBalance) {
            revert InsufficientRewardReserve(balanceAfter, requiredBalance);
        }

        // Registramos los parámetros del nuevo periodo.
        rewardRate = newRewardRate;

        reservedRewards = availableReserve + scheduledRewards;

        periodRewardsGenerated = 0;

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
    }

    // =============================================================
    // COBRO DE RECOMPENSAS
    // =============================================================

    /**
     * @notice Permite al usuario cobrar las recompensas acumuladas.
     * @dev Actualiza las recompensas antes de consultar el importe.
     *      Reduce la deuda contable antes de transferir los tokens.
     */
    function getReward() external nonReentrant {
        // Consolidamos las recompensas del usuario hasta este instante.
        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];

        if (reward > 0) {
            // Efectos: eliminamos la deuda del usuario y reducimos
            // la reserva contable antes de la transferencia externa.
            rewards[msg.sender] = 0;
            reservedRewards -= reward;

            // Interacción: transferimos las recompensas al usuario.
            bool success = rewardsToken.transfer(msg.sender, reward);

            if (!success) revert RewardsTokenTransferFailed();

            emit RewardPaid(msg.sender, reward);
        }
    }
}
