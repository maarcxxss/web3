# ERC-20 Token — Solidity & Foundry

Implementación personalizada de un token fungible compatible con el estándar **ERC-20 de Ethereum**, desarrollada en Solidity como parte de un proyecto personal de aprendizaje de Blockchain y Web3.

El proyecto explora el funcionamiento de los Smart Contracts, la implementación de los mecanismos principales de un token y la validación de su comportamiento mediante pruebas automatizadas con Foundry.

**Estado:** implementación y testing completados para la versión actual. La revisión de seguridad y la documentación técnica continúan en desarrollo.

## Características

- **ERC-20:** implementación personalizada de las funciones principales del estándar.
- **Balances y suministro:** consulta de balances y suministro total.
- **Transferencias:** `transfer`, `approve` y `transferFrom`.
- **Eventos:** `Transfer`, `Approval` y eventos relacionados con la gestión del contrato.
- **Control de acceso:** propiedad del contrato y permisos de minter.
- **Mint y burn:** creación y destrucción de tokens.
- **Supply máximo:** límite de emisión mediante `CAP`.
- **Pausado:** funciones `pause` y `unpause`.
- **Permit:** implementación personalizada basada en EIP-2612 y EIP-712 para establecer allowances mediante firmas.
- **Custom errors:** errores específicos para representar condiciones de fallo.
- **Testing:** pruebas unitarias, fuzz testing y pruebas de invariantes.
- **Code coverage:** análisis de cobertura mediante Foundry.

## Tecnologías

- Solidity
- Foundry: Forge, Anvil y Cast
- Git y GitHub
- Visual Studio Code

## Estructura del proyecto

```text
erc20/
├── src/
│   ├── IERC20.sol
│   └── MyToken.sol
├── test/
│   ├── MyToken.t.sol
│   ├── MyToken_fuzz.t.sol
│   └── MyToken_invariant.t.sol
├── script/
│   └── DeployMyToken.s.sol
├── foundry.toml
├── .gitignore
└── README.md
```

### Contratos

- `IERC20.sol`: define la interfaz ERC-20 utilizada por el proyecto.
- `MyToken.sol`: contiene la implementación personalizada del token.

### Tests

- `MyToken.t.sol`: pruebas unitarias de funciones, permisos, eventos, errores y mecanismos del contrato.
- `MyToken_fuzz.t.sol`: pruebas con entradas generadas automáticamente.
- `MyToken_invariant.t.sol`: pruebas de invariantes para verificar propiedades durante secuencias de transferencias.

### Scripts

- `DeployMyToken.s.sol`: permite desplegar el token mediante Foundry.

## Instalación y ejecución

Requisitos previos: Git y Foundry instalados.

### 1. Clonar el repositorio

```bash
git clone https://github.com/maarcxxss/web3.git
cd web3/standards/erc20
```

### 2. Instalar la dependencia de testing

El proyecto utiliza `forge-std` para las pruebas y los scripts de Foundry.

```bash
forge install foundry-rs/forge-std --no-commit
```

### 3. Compilar los contratos

```bash
forge build
```

### 4. Ejecutar todas las pruebas

```bash
forge test
```

### 5. Ejecutar las pruebas unitarias

```bash
forge test --match-path test/MyToken.t.sol
```

### 6. Ejecutar el fuzz testing

```bash
forge test --match-path test/MyToken_fuzz.t.sol
```

### 7. Ejecutar las pruebas de invariantes

```bash
forge test --match-path test/MyToken_invariant.t.sol
```

### 8. Generar un informe de cobertura

```bash
forge coverage --report summary
```

## Despliegue local con Anvil

Anvil permite ejecutar una blockchain Ethereum local para desplegar contratos y probar transacciones sin utilizar fondos reales.

### 1. Iniciar Anvil

En una terminal independiente:

```bash
anvil
```

Mantén esta terminal abierta mientras trabajas con la blockchain local.

### 2. Desplegar el token

Desde la carpeta `standards/erc20`, ejecuta:

```bash
forge script script/DeployMyToken.s.sol:DeployMyToken --rpc-url http://127.0.0.1:8545 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --unlocked --broadcast
```

El comando utiliza una cuenta predeterminada de Anvil. Comprueba que la dirección indicada aparece entre las cuentas de tu instancia local.

Al finalizar, Foundry mostrará la dirección del contrato desplegado. Utiliza esa dirección en las consultas siguientes.

### 3. Consultar el token

Sustituye `DIRECCION_CONTRATO` por la dirección que haya devuelto el despliegue.

Consultar el nombre:

```bash
cast call DIRECCION_CONTRATO "name()(string)" --rpc-url http://127.0.0.1:8545
```

Consultar el suministro total:

```bash
cast call DIRECCION_CONTRATO "totalSupply()(uint256)" --rpc-url http://127.0.0.1:8545
```

Consultar los decimales:

```bash
cast call DIRECCION_CONTRATO "decimals()(uint8)" --rpc-url http://127.0.0.1:8545
```

Consultar el balance de una cuenta:

```bash
cast call DIRECCION_CONTRATO "balanceOf(address)(uint256)" DIRECCION_CUENTA --rpc-url http://127.0.0.1:8545
```

### 4. Enviar una transferencia

Ejemplo de transferencia de 10 tokens entre dos cuentas de Anvil:

```bash
cast send DIRECCION_CONTRATO "transfer(address,uint256)" DIRECCION_DESTINO 10000000000000000000 --rpc-url http://127.0.0.1:8545 --unlocked --from DIRECCION_EMISOR
```

Con 18 decimales, `10000000000000000000` representa 10 tokens.

El comando devuelve información sobre la transacción, incluyendo su hash, el bloque, el gas utilizado y los logs generados.

**Nota:** las direcciones del contrato y los balances pertenecen a la instancia local de Anvil. Al reiniciarla, el estado puede desaparecer y será necesario volver a desplegar el contrato.

## Testing y cobertura

El proyecto utiliza tres enfoques complementarios para comprobar el comportamiento del contrato.

### Pruebas unitarias

Comprueban operaciones concretas, incluyendo transferencias, allowances, permisos, emisión y destrucción de tokens, pausado, eventos, errores y firmas `permit`.

**Resultado:** 72 pruebas unitarias superadas.

### Fuzz testing

Utiliza entradas generadas automáticamente para explorar diferentes valores y comprobar las propiedades esperadas.

Se han implementado 8 pruebas de fuzzing, con 256 casos por prueba en la configuración actual.

**Resultado:** 8 pruebas de fuzzing superadas.

### Invariant testing

Verifica propiedades que deben mantenerse durante secuencias de operaciones generadas por Foundry.

Se comprueban dos invariantes:

- `invariant_TotalSupplyEqualsBalances`: el suministro total coincide con la suma de los balances de las cuentas incluidas en el entorno de pruebas.
- `invariant_TotalSupplyRemainsConstant`: el suministro total permanece constante durante las transferencias.

La configuración actual ejecuta 256 secuencias (*runs*) con 128.000 llamadas al handler, sin reversiones ni casos descartados.

Estas invariantes corresponden al conjunto de operaciones y cuentas definido en el test actual; no representan una prueba exhaustiva de todas las funcionalidades del contrato.

### Resultados de cobertura

Resultados obtenidos mediante `forge coverage --report summary`:

| Métrica | Cobertura |
|---|---:|
| Líneas | 100 % |
| Instrucciones | 100 % |
| Ramas | 100 % |
| Funciones | 100 % |

La ejecución completa de `forge test` ha finalizado con **81 pruebas superadas, 0 fallidas y 0 omitidas**, según el resumen registrado de Foundry.

La cobertura mide qué partes del código ejecutan las pruebas. No garantiza por sí sola la ausencia de errores o vulnerabilidades. El análisis de seguridad sigue siendo una parte importante del desarrollo.

## Roadmap

- [x] Implementación personalizada del contrato ERC-20.
- [x] Gestión de balances, allowances y transferencias.
- [x] Control de acceso y permisos de minter.
- [x] Funciones de mint y burn.
- [x] Límite máximo de suministro.
- [x] Mecanismo de pausado.
- [x] Implementación de `permit`.
- [x] Pruebas unitarias.
- [x] Fuzz testing.
- [x] Invariant testing.
- [x] Cobertura del 100 % en las métricas medidas.
- [x] Script de despliegue con Foundry.
- [x] Despliegue y comprobaciones manuales en Anvil.

## Mejoras futuras

- [ ] Revisar casos límite y posibles vulnerabilidades.
- [ ] Realizar una revisión de seguridad más exhaustiva.
- [ ] Ampliar la documentación técnica y los ejemplos de interacción.
- [ ] Evaluar un despliegue en una testnet.

## Objetivo del proyecto

Este proyecto busca comprender el funcionamiento de los estándares de Ethereum y aplicar buenas prácticas de programación, testing y seguridad de Smart Contracts.

Se ha desarrollado de forma progresiva, priorizando la comprensión de la lógica del contrato, la validación de su comportamiento y la reproducibilidad de los experimentos.

Es un proyecto educativo y **no está destinado actualmente a gestionar fondos reales**.

## Autor

Proyecto personal de Ingeniería Informática centrado en Blockchain, Solidity, Smart Contracts y desarrollo Web3.

GitHub: [@maarcxxss](https://github.com/maarcxxss)
