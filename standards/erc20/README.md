# ERC-20 Token — Solidity & Foundry

Implementación personalizada de un token fungible compatible con el estándar **ERC-20 de Ethereum**, desarrollada en Solidity como parte de un proyecto personal de aprendizaje de Blockchain y Web3.

El objetivo es comprender cómo funcionan los Smart Contracts, implementar los mecanismos principales de un token y verificar su comportamiento mediante pruebas automatizadas con Foundry.

> **Estado:** implementación y testing completados para la versión actual. El proyecto incluye pruebas unitarias, fuzz testing, pruebas de invariantes y un análisis de cobertura del 100 %.

## Características

- **ERC-20:** implementación personalizada de las funciones principales del estándar.
- **Gestión de balances y supply:** consulta de balances y suministro total de tokens.
- **Transferencias:** `transfer`, `approve` y `transferFrom`.
- **Eventos:** `Transfer`, `Approval` y eventos relacionados con la gestión del contrato.
- **Control de acceso:** propietario del contrato y permisos de minter.
- **Mint y burn:** creación y destrucción de tokens.
- **Supply máximo:** límite de emisión mediante `CAP`.
- **Pausado:** funciones `pause` y `unpause` para controlar las operaciones permitidas.
- **Permit:** implementación personalizada basada en EIP-2612 y EIP-712 para establecer allowances mediante firmas.
- **Custom errors:** errores específicos para representar condiciones de fallo.
- **Unit testing:** pruebas del comportamiento esperado del contrato y sus condiciones de error.
- **Fuzz testing:** comprobación de propiedades con diferentes valores de entrada generados automáticamente.
- **Invariant testing:** verificación de propiedades que deben mantenerse durante múltiples secuencias de operaciones.
- **Code coverage:** análisis de cobertura mediante Foundry.

## Tecnologías

- Solidity
- Foundry
- Forge
- Anvil
- Cast
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
├── foundry.toml
├── .gitignore
└── README.md
```

### Contratos

- `IERC20.sol`: define la interfaz ERC-20 utilizada por el proyecto.
- `MyToken.sol`: contiene la implementación personalizada del token.

### Tests

- `MyToken.t.sol`: pruebas unitarias de las funciones, permisos, eventos, errores y mecanismos del contrato.
- `MyToken_fuzz.t.sol`: pruebas con entradas generadas automáticamente para comprobar el comportamiento del token con distintos valores.
- `MyToken_invariant.t.sol`: pruebas de invariantes para comprobar propiedades que deben mantenerse durante secuencias de transferencias.

## Instalación y ejecución

Se necesita tener Git y Foundry instalados.

### 1. Clonar el repositorio

```bash
git clone https://github.com/maarcxxss/web3.git
```

### 2. Entrar en el directorio del proyecto

```bash
cd web3/standards/erc20
```

### 3. Compilar los contratos

```bash
forge build
```

### 4. Ejecutar todas las pruebas

```bash
forge test
```

### 5. Ejecutar únicamente las pruebas unitarias

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

## Testing y cobertura

El proyecto utiliza tres enfoques complementarios para verificar el comportamiento del contrato.

### Pruebas unitarias

Comprueban el resultado esperado de operaciones concretas, incluyendo transferencias, allowances, permisos, emisión y destrucción de tokens, pausado, eventos, errores y firmas `permit`.

**Resultado:** 72 pruebas unitarias superadas.

### Fuzz testing

Las pruebas de fuzzing utilizan valores generados automáticamente para explorar diferentes entradas y comprobar que las funciones respetan las propiedades esperadas.

Se han implementado 8 pruebas de fuzzing, con 256 casos por prueba en la configuración actual.

**Resultado:** 8 pruebas superadas.

### Invariant testing

Las pruebas de invariantes verifican propiedades que deben mantenerse durante secuencias de operaciones ejecutadas por Foundry.

Se comprueban dos propiedades:

- `invariant_TotalSupplyEqualsBalances`: el suministro total coincide con la suma de los balances de las cuentas incluidas en el entorno de pruebas.
- `invariant_TotalSupplyRemainsConstant`: el suministro total permanece constante durante las transferencias.

La configuración actual ejecuta 256 secuencias (*runs*) con 128.000 llamadas al handler, sin reversiones ni casos descartados.

Estas invariantes corresponden al conjunto de operaciones y cuentas definidos en el test actual.

### Resultados de cobertura

Resultados obtenidos mediante `forge coverage --report summary`:

| Métrica | Resultado |
|---|---:|
| Líneas | 100 % |
| Instrucciones | 100 % |
| Ramas | 100 % |
| Funciones | 100 % |

La cobertura del contrato `MyToken.sol` es del 100 % en las cuatro métricas.

La ejecución completa de `forge test` ha finalizado con **81 pruebas superadas, 0 fallidas y 0 omitidas**, según el resumen de Foundry.

La cobertura mide qué partes del código ejecutan las pruebas. No garantiza por sí sola la ausencia de errores o vulnerabilidades, por lo que el análisis de seguridad continúa siendo una parte importante del desarrollo.

## Roadmap

- [x] Implementación del contrato ERC-20 personalizado.
- [x] Gestión de balances, allowances y transferencias.
- [x] Control de acceso y permisos de minter.
- [x] Funciones de mint y burn.
- [x] Límite máximo de suministro.
- [x] Mecanismo de pausado.
- [x] Implementación de `permit`.
- [x] Pruebas unitarias.
- [x] Pruebas de fuzzing.
- [x] Pruebas de invariantes.
- [x] Cobertura del 100 % en líneas, instrucciones, ramas y funciones.
- [ ] Revisar seguridad y casos límite adicionales.
- [ ] Realizar una revisión de seguridad más exhaustiva.
- [ ] Documentar y ejecutar el despliegue en una blockchain local con Anvil.
- [ ] Preparar documentación técnica y ejemplos de interacción con el contrato.

## Objetivo de aprendizaje

El proyecto busca comprender el funcionamiento interno de los estándares de Ethereum y desarrollar buenas prácticas de programación, testing y seguridad de Smart Contracts.

Se ha construido de forma progresiva, priorizando la comprensión de la lógica del contrato, la validación de su comportamiento y el análisis de sus resultados.

Es un proyecto educativo en desarrollo y no está destinado actualmente a gestionar fondos reales.

## Autor

Proyecto personal de aprendizaje de Ingeniería Informática, centrado en Blockchain, Solidity, Smart Contracts y desarrollo Web3.

GitHub: [@maarcxxss](https://github.com/maarcxxss)