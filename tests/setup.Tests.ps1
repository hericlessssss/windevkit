Describe "Validacao Final do Ambiente de DEV (Sanity Check)" {
    
    Context "Ecossistema Java" {
        It "O compilador CLI ('java') deve estar no PATH" {
            $javaCmd = Get-Command java -ErrorAction SilentlyContinue
            $javaCmd | Should Not BeNullOrEmpty
        }
        
        It "A Variavel 'JAVA_HOME' deve estar mapeada globalmente direcionando para o Eclipse Temurin 21" {
            $javaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
            $javaHome | Should Match "jdk-21\."
        }

        It "A versao CLI default em execucao ativa deve refletir Java 21 LTS" {
            $javaVersion = (java -version 2>&1) -join " "
            $javaVersion | Should Match "version `"21"
        }
    }

    Context "Ecossistema Node.Js e NVM" {
        It "NVM for Windows deve orquestrar confiavelmente as versoes" {
            $nvmVersion = nvm version 2>&1
            $nvmVersion | Should Not BeNullOrEmpty
        }

        It "Binarios interativos do Node ('node') devem acessar a familia v24 obrigatoriamente" {
            $nodeVersion = node -v 2>&1
            $nodeVersion | Should Not BeNullOrEmpty
            $nodeVersion | Should Match "^v24"
        }
        
        It "Gerenciador do ecossistema Node ('npm') deve expor metadados de versao com integridade logica" {
            $npmVersion = npm -v 2>&1
            $npmVersion | Should Match "^[0-9]{1,2}\."
        }
    }

    Context "Ecossistema Python e Pipelines" {
        It "Interpretador 'python' expoe a versao 3.12 com sucesso" {
            $pythonVersion = (python --version 2>&1) -join " "
            $pythonVersion | Should Match "Python 3\.12"
        }

        It "A ferramenta de provisionamento 'pip' roda com integridade contra a versao instalada do Python" {
            $pipVersion = (pip --version 2>&1) -join " "
            $pipVersion | Should Match "python 3\.12"
        }
    }

    Context "Orquestracao WSL2 e Linux Base" {
        It "Hypervisor do WSL lista Canonical Ubuntu como integracao funcional e amarrado a API Versao 2" {
            # Pega o output e remove caracteres nulos/estranhos comuns no encoding do WSL
            $wslOutputText = (wsl.exe -l -v 2>&1 | Out-String).Replace("`0", "")
            if ($wslOutputText -match "Ubuntu") {
                $wslOutputText | Should Match "2"
            }
            else {
                Write-Host " [Aviso] Ubuntu nao listado. Rode 'wsl --install -d Ubuntu' se ja reiniciou." -ForegroundColor Yellow
                $wslOutputText | Should Match "Ubuntu"
            }
        }
    }

    Context "CLI do Docker e WSL2 Backends" {
        It "Console root do Docker (docker cli) esta injetado na session path" {
            $dockerVersion = (docker --version 2>&1) -join " "
            $dockerVersion | Should Match "Docker version"
        }

        It "O Plugin Docker Compose V2 deve ser acessivel usando build nativo" {
            $composeVersion = (docker compose version 2>&1) -join " "
            $composeVersion | Should Match "Docker Compose version"
        }

        It "O processo daemon do Docker esta hospedado em memoria pronto para responder pipes" {
            $dockerInfo = (docker info 2>&1) -join " "
            $dockerInfo | Should Not Match "error during connect"
        }
    }
}
