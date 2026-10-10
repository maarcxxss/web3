# ERC-20 Token — Solidity & Foundry

Implementación personalizada de un token fungible compatible con el estándar **ERC-20 de Ethereum**, desarrollada en Solidity como parte de un proyecto personal de aprendizaje de Blockchain y Web3.

El objetivo es comprender cómo funcionan los Smart Contracts, implementar los mecanismos principales de un token y verificar su comportamiento mediante pruebas automatizadas con Foundry.

> **Estado:** desarrollo en curso. Las pruebas unitarias y el análisis de cobertura están completados para la versión actual. El fuzz testing y las pruebas de invariantes están pendientes.

## Características

- **ERC-20:** implementación de las funciones principales del estándar.
- **Gestión de balances y supply:** consulta de balances y suministro total.
- **Transferencias:** `transfer`, `approve` y `transferFrom`.
- **Eventos:** `Transfer`, `Approval` y eventos relacionados con la pausa.
- **Control de acceso:** propietario del contrato y permisos de minter.
- **Mint y burn:** creación y destrucción de tokens.
- **Supply máximo:** límite de emisión mediante `CAP`.
- **Pausado:** funciones `pause` y `unpause` para controlar determinadas operaciones.
- **Permit:** implementación personalizada de firmas basada en EIP-2612 y EIP-712.
- **Custom errors:** errores específicos para representar condiciones de fallo.
- **Testing:** pruebas automatizadas con Forge y análisis de cobertura.

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

Los archivos de fuzzing e invariantes forman parte de la siguiente etapa de desarrollo; su inclusión en la estructura no implica que las pruebas estén completadas.

## Instalación y ejecución

Se necesita tener Git y Foundry instalados.

Clonar el repositorio:

```bash
git clone https://github.com/maarcxxss/web3.git
```

Entrar en el directorio del proyecto ERC-20:

```bash
cd web3/standards/erc20
```

Compilar los contratos:

```bash
forge build
```

Ejecutar las pruebas:

```bash
forge test
```

Generar un informe de cobertura:

```bash
forge coverage --report summary
```

## Testing y cobertura

La suite de pruebas unitarias cubre el comportamiento de las funciones del token, los permisos, los eventos, las condiciones de error, el pausado y el mecanismo `permit`.

Resultados obtenidos en la versión actual:

| Métrica | Cobertura |
|---|---:|
| Líneas | 100 % |
| Instrucciones | 100 % |
| Ramas | 100 % |
| Funciones | 100 % |

La cobertura se ha calculado con `forge coverage --report summary`. Estos resultados describen la cobertura de código alcanzada por los tests; no constituyen por sí solos una auditoría de seguridad.

## Roadmap

- [x] Implementación del contrato ERC-20 personalizado.
- [x] Gestión de balances, allowances y transferencias.
- [x] Control de acceso y permisos de minter.
- [x] Funciones de mint y burn.
- [x] Límite máximo de suministro.
- [x] Mecanismo de pausado.
- [x] Implementación de `permit`.
- [x] Pruebas unitarias.
- [x] Cobertura del 100 % en líneas, instrucciones, ramas y funciones.
- [ ] Implementar y validar pruebas de fuzzing.
- [ ] Implementar y validar pruebas de invariantes.
- [ ] Revisar seguridad y casos límite.
- [ ] Documentar el proceso de despliegue en una blockchain local con Anvil.

## Objetivo de aprendizaje

El proyecto busca comprender el funcionamiento interno de los estándares de Ethereum y desarrollar buenas prácticas de programación, testing y seguridad de Smart Contracts.

Es un proyecto educativo en desarrollo y no está destinado actualmente a gestionar fondos reales.

## Autor

Proyecto personal de aprendizaje de Ingeniería Informática, centrado en Blockchain, Solidity, Smart Contracts y desarrollo Web3.