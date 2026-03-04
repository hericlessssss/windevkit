# 💻 Kit de Onboarding Microsoft: Developer Workspace

Este kit automatiza a implantação de um ambiente de desenvolvimento moderno no Windows 11.

## Componentes
- Java: Eclipse Temurin 21 (default) & 17
- Node.js: v24 (via NVM)
- Python: 3.12
- WSL2: Ubuntu LTS
- Docker: Docker Desktop (WSL2 Backend)

## Como Executar

1. Abra o PowerShell como **Administrador**.
2. Execute o script:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; .\setup.ps1
```

### Parâmetros Opcionais:
- `-DryRun`: Simula sem instalar.
- `-InstallJava17`: Instala o JDK 17 adicional.
- `-InstallNode20`: Instala o Node v20 adicional.
- `-InstallPython311`: Instala o Python 3.11 adicional.
- `-SkipDocker`: Pula a instalação do Docker.
- `-SkipWSL`: Pula a configuração do WSL.

## Validação

Para rodar os testes automatizados (Pester):
```powershell
Install-Module Pester -Force -SkipPublisherCheck
Invoke-Pester .\tests\setup.Tests.ps1
```

## Checklist Manual
- [ ] `java -version`
- [ ] `node -v`
- [ ] `python --version`
- [ ] `wsl -l -v`
- [ ] `docker info`