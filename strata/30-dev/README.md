# Developer Stratum (`30-dev`)

This stratum manages development runtimes, SDKs, compilers, package managers, and editors provisioned on the workstation.

---

## Toolchain & Runtime Matrix

| Ecosystem | Primary Binary / SDK | Version / Source |
|---|---|---|
| **Rust** | `rustc`, `cargo` | Stable via `rustup` |
| **Flutter & Dart** | `flutter`, `dart` | Git checkout |
| **Node.js** | `node`, `npm`, `pnpm` | v20+ / Node.js installer |
| **Python** | `python`, `py` | Python 3.15 |
| **.NET** | `dotnet` | .NET 10 / 11 preview |
| **Java** | `java`, `javac` | Microsoft OpenJDK 17 |
| **R** | `R` | CRAN RProject |
| **C/C++** | MSVC 2022 / Clang | Visual Studio 2026 Community & Build Tools |

---

## Package Manager Ecosystem

1. **WinGet**: Primary manager for GUI software, runtimes, and system redistributables. Manifest exported at [`strata/10-os/windows/winget.json`](../../strata/10-os/windows/winget.json).
2. **Scoop**: CLI-focused tools and terminal utilities. Manifest declared at [`strata/10-os/windows/scoop.json`](../../strata/10-os/windows/scoop.json).
3. **Chocolatey**: Auxiliary package management for legacy packages.

---

## Editor & IDE Stacks

- **Zed**: Lightweight, GPU-accelerated code editor (`strata/40-apps/zed/`).
- **VS Code Insiders**: Configured with Remote-SSH and Docker integration (`strata/40-apps/vscode/`).
- **Visual Studio Community 2026 / 2022 Build Tools**: Heavy C++, C#, and game engine builds.
- **JetBrains Rider**: High-performance .NET & Unity/Unreal IDE.
- **Google Antigravity**: AI agent pairing and interactive coding assistant.
