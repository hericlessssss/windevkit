<#
.SYNOPSIS
Kit de Onboarding Automatizado - Ambiente DEV x64 no Windows 11

.DESCRIPTION
Instala e configura via WinGet: Java 21 LTS (default) & 17, Node.js v24 (via NVM),
Python 3.12, habilitando recursos básicos de Linux (WSL2/Ubuntu) e o Docker Desktop.
#>

[CmdletBinding()]
param (
    [switch]$DryRun,
    [switch]$InstallJava17,
    [switch]$InstallPython311,
    [switch]$InstallNode20,
    [switch]$SkipDocker,
    [switch]$SkipWSL
)

$ErrorActionPreference = "Stop"
$LogDir = "$PSScriptRoot\logs"
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile = Join-Path $LogDir "setup-$Timestamp.log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "STEP")]
        [string]$Level = "INFO"
    )
    $LogLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $LogLine

    switch ($Level) {
        "ERROR" { Write-Host $LogLine -ForegroundColor Red }
        "WARN" { Write-Host $LogLine -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $LogLine -ForegroundColor Green }
        "STEP" { Write-Host "`n>>> $Message" -ForegroundColor Cyan }
        Default { Write-Host $LogLine }
    }
}

function Write-Step { param([string]$Message) Write-Log -Message $Message -Level "STEP" }

function Assert-Admin {
    Write-Step "Validando permissões de execução (Administrator)..."
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($DryRun) {
        if ($isAdmin) {
            Write-Log "Execucao como Admin confirmada (DryRun)." -Level "SUCCESS"
        }
        else {
            Write-Log "Aviso: Nao e Admin, mas prosseguindo devido ao -DryRun." -Level "WARN"
        }
        return
    }

    if (-not $isAdmin) {
        Write-Log "Permissão negada. O script precisa de privilégios de Administrador." -Level "ERROR"
        Write-Log "Abra um terminal PowerShell (ou Windows Terminal) como Administrador e execute novamente." -Level "WARN"
        exit 1
    }
    Write-Log "Execucao como Admin confirmada." -Level "SUCCESS"
}

function Assert-WinGet {
    Write-Step "Validando o gerenciador de pacotes WinGet..."
    try {
        $wingetPath = Get-Command winget -ErrorAction Stop
        Write-Log "WinGet operacional. Fonte: $($wingetPath.Source)" -Level "SUCCESS"
    }
    catch {
        Write-Log "WinGet ausente. Por favor, instale ou atualize o 'Instalador de Aplicativo' pela Microsoft Store." -Level "ERROR"
        exit 1
    }
}

function Invoke-WinGetInstall {
    param([string]$PackageId, [string]$Version = "")
    
    if ($DryRun) {
        Write-Log "[DryRun] Pacote avaliado para instalacao: $PackageId" -Level "INFO"
        return $true
    }

    $args = @("install", "--id", $PackageId, "--exact", "--accept-package-agreements", "--accept-source-agreements", "--silent")
    if ($Version) { $args += "--version"; $args += $Version }

    try {
        Write-Log "Disparando via WinGet: $PackageId" -Level "INFO"
        $process = Start-Process winget -ArgumentList $args -NoNewWindow -Wait -PassThru
        
        # exit code -1978335189 no winget indica "já instalado / versão atual já presente"
        if ($process.ExitCode -ne 0 -and $process.ExitCode -ne -1978335189) { 
            Write-Log "Falha na instalacao de $PackageId (Código de Saida: $($process.ExitCode))" -Level "WARN"
            return $false
        }
        else {
            Write-Log "$PackageId providenciado/instalado com sucesso." -Level "SUCCESS"
            return $true
        }
    }
    catch {
        Write-Log "Erro de execucao do WinGet para $PackageId : $_" -Level "ERROR"
        return $false
    }
}

function Enable-WindowsFeaturesForWSL {
    if ($SkipWSL) { return }
    Write-Step "Habilitando recursos de Virtualização e WSL..."
    if ($DryRun) { Write-Log "[DryRun] Processaria VirtualMachinePlatform e Subsystem-Linux." -Level "INFO"; return }
    
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction Stop | Out-Null
        Write-Log "Virtualizacao e Linux ativados. (Possivelmente exigindo reboot posterior)" -Level "SUCCESS"
    }
    catch {
        Write-Log "Falha ao manipular as Features do Windows: $_" -Level "ERROR"
    }
}

function Install-WSLAndDistro {
    if ($SkipWSL) { return }
    Write-Step "Validando distribuicoes no WSL e inicializando Ubuntu (Padrão)..."
    if ($DryRun) { Write-Log "[DryRun] Faria deploy logico de WSL 2 + Ubuntu LTS." -Level "INFO"; return }

    try {
        $wslStatus = (wsl -l -v 2>&1) -join " "
        if ($wslStatus -match "Ubuntu") {
            Write-Log "WSL/Ubuntu já esta presente e vivo no sistema." -Level "SUCCESS"
            wsl --set-default-version 2 | Out-Null
        }
        else {
            Write-Log "Disparando instalador nativo do Windows Subsystem for Linux (--install)..." -Level "INFO"
            Start-Process wsl -ArgumentList "--install", "--no-launch" -NoNewWindow -Wait
            Write-Log "Ubuntu LTS ancorado via WSL." -Level "SUCCESS"
        }
    }
    catch {
        Write-Log "Engasgo durante provisionamento WSL: $_" -Level "ERROR"
    }
}

function Install-Java {
    Write-Step "Provisionando Java Ecosystem (Eclipse Temurin)..."
    
    if ($InstallJava17) {
        Write-Log "Adicionando Java 17 LTS lado-a-lado..." -Level "INFO"
        Invoke-WinGetInstall -PackageId "EclipseAdoptium.Temurin.17.JDK" | Out-Null
    }
    
    Write-Log "Semeando/Atualizando Java 21 LTS (Branch Padrão do Kit)..." -Level "INFO"
    Invoke-WinGetInstall -PackageId "EclipseAdoptium.Temurin.21.JDK" | Out-Null
}

function Install-NVMAndNode {
    Write-Step "Provisionando NVM for Windows e Ecossistema Node.js..."
    
    Invoke-WinGetInstall -PackageId "CoreyButler.NVMforWindows" | Out-Null
    
    if ($DryRun) { Write-Log "[DryRun] Executaria 'nvm install 24' e configuraria default." -Level "INFO"; return }

    # Força a leitura das variaveis de ambiente na sessao atual do PS
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    try {
        $nvmCommand = Get-Command nvm -ErrorAction SilentlyContinue
        if (-not $nvmCommand) {
            $userNvm = "$env:APPDATA\nvm\nvm.exe"
            if (Test-Path $userNvm) { Set-Alias nvm $userNvm -Scope Local }
            $nvmCommand = Get-Command nvm -ErrorAction SilentlyContinue
        }

        if ($nvmCommand) {
            if ($InstallNode20) {
                Write-Log "Requisitando Node 20 para o Pool NVM..." -Level "INFO"
                nvm install 20 | Out-Null
            }
            Write-Log "Processando Node LTS 24..." -Level "INFO"
            nvm install 24 | Out-Null
            nvm use 24 | Out-Null
            Write-Log "NPM local e Node 24 ativados na arvore nativa." -Level "SUCCESS"
        }
        else {
            Write-Log "'nvm' nao entrou em hot-reload no PATH. Após abrir um novo terminal, certifique-se de executar: 'nvm install 24' seguida de 'nvm use 24'" -Level "WARN"
        }
    }
    catch {
        Write-Log "Falha na sintaxe do NVM: $_" -Level "ERROR"
    }
}

function Install-Python {
    Write-Step "Provisionando Engine do Python e Pip..."
    
    if ($InstallPython311) {
        Write-Log "Aguardando instalacao Python 3.11 pregressa..." -Level "INFO"
        Invoke-WinGetInstall -PackageId "Python.Python.3.11" | Out-Null
    }

    Write-Log "Processando instalador do Python 3.12 (Padrão)..." -Level "INFO"
    Invoke-WinGetInstall -PackageId "Python.Python.3.12" | Out-Null
}

function Install-DockerDesktop {
    if ($SkipDocker) { return }
    Write-Step "Armando Docker Desktop via WinGet..."
    Invoke-WinGetInstall -PackageId "Docker.DockerDesktop" | Out-Null
}

function Configure-EnvironmentVariables {
    Write-Step "Higienizando Variáveis de Ambiente..."
    if ($DryRun) { Write-Log "[DryRun] Configuraria/Validaria JAVA_HOME global." -Level "INFO"; return }
    
    try {
        $java21Path = "C:\Program Files\Eclipse Adoptium\jdk-21.*"
        $foundJava = Get-Item -Path $java21Path -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($foundJava) {
            [Environment]::SetEnvironmentVariable("JAVA_HOME", $foundJava.FullName, [EnvironmentVariableTarget]::Machine)
            Write-Log "JAVA_HOME setado no Sistema para: $($foundJava.FullName)" -Level "SUCCESS"
        }
        else {
            Write-Log "O diretorio padrao do JDK 21 nao foi identificado para linkar JAVA_HOME." -Level "WARN"
        }
    }
    catch {
        Write-Log "Erro nas variaveis logicas do sistema $_" -Level "ERROR"
    }
}

function Start-Or-Verify-DockerDesktop {
    if ($SkipDocker) { return }
    Write-Step "Iniciando processo do Docker Engine (Backend)..."
    if ($DryRun) { Write-Log "[DryRun] Executaria binario do Docker em Background." -Level "INFO"; return }
    
    $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerExe) {
        $process = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
        if (-not $process) {
            Write-Log "Ouvindo serviço do Docker Desktop (pode levar 3 min para aquecer a engine)..." -Level "INFO"
            Start-Process $dockerExe -NoNewWindow
            Write-Log "Background Watcher disparado." -Level "SUCCESS"
        }
        else {
            Write-Log "Docker Desktop identificado como saudavel na memoria." -Level "SUCCESS"
        }
    }
    else {
        Write-Log "Binario da UI do Docker não rastreado em caminho padrao." -Level "WARN"
    }
}

function Validate-Tools {
    Write-Step "Rotina de Encerramento e Refresh de Ambiente"
    if ($DryRun) { Write-Log "[DryRun] Finalizaria script sem modificacoes." -Level "INFO"; return }
    
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Main {
    Write-Log "" -Level "INFO"
    Write-Log "==========================================================" -Level "INFO"
    Write-Log " BOOTSTRAP DO AMBIENTE DE DESENVOLVEDOR - ONBOARDING " -Level "INFO"
    Write-Log "==========================================================" -Level "INFO"

    try {
        Assert-Admin
        Assert-WinGet
        Enable-WindowsFeaturesForWSL
        Install-WSLAndDistro
        Install-Java
        Install-NVMAndNode
        Install-Python
        Install-DockerDesktop
        Configure-EnvironmentVariables
        Start-Or-Verify-DockerDesktop
        Validate-Tools

        Write-Log "" -Level "INFO"
        Write-Log "==========================================================" -Level "SUCCESS"
        Write-Log " AMBIENTE IMPLANTADO COM SUCESSO! " -Level "SUCCESS"
        Write-Log "==========================================================" -Level "SUCCESS"
        Write-Log "1. SE você instalou WSL ou Docker hoje, REINICIE SEU COMPUTADOR agora." -Level "WARN"
        Write-Log "2. FECHE ESTA JANELA. Abra um (NOVO) terminal sem ser admin para recarregar as paths." -Level "WARN"
        Write-Log "3. Acompanhe os comandos de test coverage TDD no Pester contidos no README." -Level "INFO"
    }
    catch {
        Write-Log "Crash no executor do Setup: $_" -Level "ERROR"
        exit 1
    }
}

Main
