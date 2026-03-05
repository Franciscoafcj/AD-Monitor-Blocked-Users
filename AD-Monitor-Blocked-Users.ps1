# ============== CONFIGURAÇÕES INICIAIS ==============
if (-not (Get-Module -Name ActiveDirectory)) {
    Import-Module ActiveDirectory -ErrorAction Stop
}

$DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name
# cache simples para resolver nomes de máquina apenas uma vez
$cacheDns = @{}

# ============== ESCOLHA DE MONITORAMENTO ==============
function Get-MonitoringChoice {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        MONITOR DE BLOQUEIOS - ACTIVE DIRECTORY   ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║ Selecione o tipo de monitoramento:               ║" -ForegroundColor White
    Write-Host "║                                                  ║"
    Write-Host "║ 1) Monitorar TODOS os usuários                   ║" -ForegroundColor Yellow
    Write-Host "║ 2) Monitorar um USUÁRIO ESPECÍFICO               ║" -ForegroundColor Green
    Write-Host "║                                                  ║"
    Write-Host "║ Pressione 1 ou 2...                              ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $choice = $null
    while ($choice -notin @('1', '2')) {
        $choice = Read-Host "Digite sua opção (1 ou 2)"
        
        if ($choice -eq '2') {
            $usuario = Read-Host "Digite o nome do usuário para monitorar (ex: francisco.silva)"
            return @{
                Tipo = "Especifico"
                Usuario = $usuario
            }
        }
        elseif ($choice -eq '1') {
            return @{
                Tipo = "Todos"
                Usuario = $null
            }
        }
        else {
            Write-Host "Opção inválida! Digite 1 ou 2" -ForegroundColor Red
        }
    }
}

# ============== ANÁLISE DO DISPOSITIVO DE ORIGEM ==============
function Get-SourceAnalysis {
    param([string]$CallerComputer)

    if ([string]::IsNullOrWhiteSpace($CallerComputer) -or $CallerComputer -eq "-") {
        return @{
            IP = "N/A"
            Suspeita = "Origem Oculta. Causas comuns: Celular via ActiveSync/Exchange, Autenticação RADIUS/NPS (Wi-Fi), ou mapeamento de rede antigo em máquina fora do domínio."
        }
    }

    # usa cache simples para não resolver o mesmo nome repetidas vezes
    if (-not $cacheDns.ContainsKey($CallerComputer)) {
        try {
            $cacheDns[$CallerComputer] = (Resolve-DnsName -Name $CallerComputer -Type A -ErrorAction SilentlyContinue).IPAddress[0]
        } catch {
            $cacheDns[$CallerComputer] = $null
        }
    }

    $ip = if ($cacheDns[$CallerComputer]) { $cacheDns[$CallerComputer] } else { "Não resolvido" }

    $suspeita = "Estação de Trabalho / Dispositivo Padrão. (Verifique Gerenciador de Credenciais ou Tarefas Agendadas)."
    
    if ($CallerComputer -match "(?i)EXCH|MAIL|OWA|WEB") {
        $suspeita = "Servidor de E-mail/Web. 📱 Forte indício de celular com senha desatualizada."
    } elseif ($CallerComputer -match "(?i)DC0|AD0|SRV-AD") {
        $suspeita = "Domain Controller. 🔄 Bloqueio via autenticação direta. Verifique Wi-Fi (NPS), VPN ou scripts."
    } elseif ($CallerComputer -match "(?i)VPN|FW|FIREWALL") {
        $suspeita = "Gateway/VPN. 🌍 Tentativa de conexão externa ou ataque de força bruta."
    } elseif ($CallerComputer -match "(?i)FS|FILE|ARQUIVO") {
        $suspeita = "File Server. 📁 Há um mapeamento de rede antigo usando as credenciais."
    }

    return @{
        IP = $ip
        Suspeita = $suspeita
    }
}

# ============== FORMATAÇÃO DA SAÍDA ==============
function Format-LockoutEvent {
    param(
        $evento,
        $TargetUserName,
        $CallerComputer
    )
    
    $TimeCreated = $evento.TimeCreated
    $Analysis = Get-SourceAnalysis -CallerComputer $CallerComputer

    Write-Host "`n==================================================" -ForegroundColor Red
    Write-Host " 🚨 BLOQUEIO DETECTADO " -ForegroundColor Yellow -BackgroundColor DarkRed
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "👤 Usuário:        $TargetUserName" -ForegroundColor Cyan
    Write-Host "🕒 Data/Hora:      $TimeCreated" -ForegroundColor White
    $DisplayComputer = if ([string]::IsNullOrWhiteSpace($CallerComputer) -or $CallerComputer -eq "-") { "Desconhecido/Oculto" } else { $CallerComputer }
    Write-Host "💻 Disp. de Origem: $DisplayComputer" -ForegroundColor Magenta
    Write-Host "🌐 IP Resolvido:    $($Analysis.IP)" -ForegroundColor Magenta
    Write-Host "🔎 Diagnóstico:    $($Analysis.Suspeita)" -ForegroundColor Green
    Write-Host "--------------------------------------------------" -ForegroundColor Gray
}

# ============== MONITORAMENTO ==============
# Nota: Modo local removido. O monitor sempre executa buscas nos DCs via PSRemoting
# e, se ocorrerem falhas, apenas registra o erro e continua tentando nos ciclos
# subsequentes; não mais troca para busca local.
function Start-ADLockoutMonitor {
    param($MonitoringChoice)
    
    $MonitorEspecifico = ($MonitoringChoice.Tipo -eq "Especifico")
    $UsuarioAlvo = $MonitoringChoice.Usuario
    
    Clear-Host
    
    if ($MonitorEspecifico) {
        Write-Host "🔍 MONITOR DE BLOQUEIOS - USUÁRIO ESPECÍFICO" -ForegroundColor Green
        Write-Host "👤 Usuário monitorado: $UsuarioAlvo" -ForegroundColor Yellow
    } else {
        Write-Host "🔍 MONITOR DE BLOQUEIOS - ACTIVE DIRECTORY (TODOS)" -ForegroundColor Green
    }
    
    Write-Host "Iniciando monitoramento em: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor White
    Write-Host "Servidores DC: $($DCs -join ', ')" -ForegroundColor Cyan
    Write-Host "Modo: Remoto (PSRemoting) 🌐" -ForegroundColor Cyan
    Write-Host "Motor de Busca: Paralelo (Alta Velocidade) ⚡" -ForegroundColor DarkYellow
    Write-Host "Pressione Ctrl+C para sair`n" -ForegroundColor Yellow
    Write-Host "✅ Monitoramento ativo - aguardando bloqueios..." -ForegroundColor Green
    Write-Host "" 
    
    $lastChecked = (Get-Date).AddDays(-7) # busca eventos dos últimos 7 dias no primeiro ciclo, depois só os novos
    $contadorEspecifico = 0
    $processedEvents = [System.Collections.Generic.HashSet[string]]::new()
    $cicloContagem = 0
    $failureCount = 0    # contador de tentativas de PSRemoting com falha
    
    while ($true) {
        $cicloContagem++
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Ciclo #$cicloContagem - Verificando eventos..." -ForegroundColor Gray -NoNewline
        
        # O ScriptBlock que será enviado e executado dentro de todos os DCs simultaneamente
        $ScriptBloco = {
                $threshold = $using:lastChecked
                $eventos = Get-WinEvent -FilterHashtable @{ 
                    LogName   = 'Security'
                    ID        = 4740
                    StartTime = $threshold
                } -ErrorAction SilentlyContinue

                if ($eventos) {
                    foreach ($evt in $eventos) {
                        # Extrai dados do evento - Properties é um array, ordem pode variar
                        $props = @{}
                        for ($i = 0; $i -lt $evt.Properties.Count; $i++) {
                            # Índices fixos para evento 4740: TargetUserName (0), TargetDomainName (1), TargetSid (2), CallerComputer (3)
                            if ($i -eq 0) { $props['TargetUserName'] = $evt.Properties[$i].Value }
                            if ($i -eq 3) { $props['CallerComputer'] = $evt.Properties[$i].Value }
                        }

                        [PSCustomObject]@{
                            RecordId       = $evt.RecordId
                            TimeCreated    = $evt.TimeCreated
                            TargetUserName = $props['TargetUserName']
                            CallerComputer = $props['CallerComputer']
                            OrigemDC       = $env:COMPUTERNAME
                        }
                    }
                }
            }
        
        try {
            # Executa o bloco de código em TODOS os DCs ao mesmo tempo usando PSRemoting
            $resultados = Invoke-Command -ComputerName $DCs -ScriptBlock $ScriptBloco -ErrorAction Stop
            
            # chamada bem-sucedida, limpar contador de falhas
            $failureCount = 0
            
            if ($resultados) {
                # Ordena todos os eventos de todos os DCs cronologicamente
                $resultadosOrdenados = $resultados | Sort-Object TimeCreated
                
                foreach ($evento in $resultadosOrdenados) {
                    $uniqueEventId = "$($evento.OrigemDC)-$($evento.RecordId)"
                    
                    if ($processedEvents.Add($uniqueEventId)) {
                        $userName = $evento.TargetUserName
                        $callerComputer = $evento.CallerComputer
                        $dcNome = $evento.OrigemDC
                        
                        if ($MonitorEspecifico) {
                            if ($userName -ieq $UsuarioAlvo) {
                                $contadorEspecifico++
                                Write-Host "`n[OCORRÊNCIA #$contadorEspecifico PARA $UsuarioAlvo NO DC $dcNome]" -ForegroundColor DarkYellow
                                Format-LockoutEvent -Event $evento -TargetUserName $userName -CallerComputer $callerComputer
                            }
                        } else {
                            Write-Host "`n[OCORRÊNCIA REGISTRADA NO DC $dcNome]" -ForegroundColor DarkGray
                            Format-LockoutEvent -Event $evento -TargetUserName $userName -CallerComputer $callerComputer
                        }
                    }
                }
            }
            Write-Host " ✅" -ForegroundColor Green
        } catch {
            $failureCount++
            Write-Host " ❌" -ForegroundColor Red
            Write-Host ""
            Write-Host "⚠️  ERRO DE PSRemoting - Detalhes:" -ForegroundColor Red
            
            $errorMsg = $_.Exception.Message
            $errorCode = $_.Exception.HResult
            $errorType = $_.Exception.GetType().Name
            $errorLine = $_.InvocationInfo.ScriptLineNumber
            
            Write-Host "   • Tipo de Erro: $errorType" -ForegroundColor Yellow
            Write-Host "   • Código: 0x$($errorCode.ToString('X8'))" -ForegroundColor Yellow
            Write-Host "   • Linha: $errorLine" -ForegroundColor Yellow
            Write-Host "   • Mensagem: $errorMsg" -ForegroundColor Red
            
            # Análise detalhada do tipo de erro
            if ($errorMsg -match "timeout|WinRM|timed out|TimeoutException") {
                Write-Host "   💡 Diagnóstico: Timeout na comunicação com DCs" -ForegroundColor Cyan
                Write-Host "   ✓ Soluções:" -ForegroundColor Green
                Write-Host "       1. Verificar conectividade com ADC (ping, telnet 5985)" -ForegroundColor Green
                Write-Host "       2. Aumentar timeout em Invoke-Command: -OperationTimeoutSec" -ForegroundColor Green
                Write-Host "       3. Verificar WinRM nos DCs: winrm get winrm/config" -ForegroundColor Green
            }
            elseif ($errorMsg -match "Access Denied|Acesso Negado|Unauthorized|permission") {
                Write-Host "   💡 Diagnóstico: Erro de autenticação ou permissão" -ForegroundColor Cyan
                Write-Host "   ✓ Soluções:" -ForegroundColor Green
                Write-Host "       1. Executar como Administrador de Domínio" -ForegroundColor Green
                Write-Host "       2. Verificar Trusted Hosts: Get-Item WSMan:\localhost\Client\TrustedHosts" -ForegroundColor Green
                Write-Host "       3. Adicionar DC aos Trusted Hosts se necessário" -ForegroundColor Green
            }
            elseif ($errorMsg -match "não está conectado|not connected|WinRM não está") {
                Write-Host "   💡 Diagnóstico: WinRM desabilitado ou não acessível" -ForegroundColor Cyan
                Write-Host "   ✓ Soluções:" -ForegroundColor Green
                Write-Host "       1. Habilitar PSRemoting no DC: Enable-PSRemoting -Force" -ForegroundColor Green
                Write-Host "       2. Verificar firewall: Get-NetFirewallRule -Name 'Windows Remote*'" -ForegroundColor Green
                Write-Host "       3. Reiniciar WinRM: Restart-Service WinRM" -ForegroundColor Green
            }
            elseif ($errorMsg -match "firewall|port|porta") {
                Write-Host "   💡 Diagnóstico: Possível bloqueio de firewall" -ForegroundColor Cyan
                Write-Host "   ✓ Soluções:" -ForegroundColor Green
                Write-Host "       1. Verificar regras de firewall (portas 5985/5986)" -ForegroundColor Green
                Write-Host "       2. Testar conectividade: Test-NetConnection -ComputerName DC -Port 5985" -ForegroundColor Green
                Write-Host "       3. Permitir tráfego WSMan no firewall" -ForegroundColor Green
            }
            elseif ($errorMsg -match "host|resolvido|DNS|não encontrado") {
                Write-Host "   💡 Diagnóstico: Erro de resolução DNS ou nome inválido" -ForegroundColor Cyan
                Write-Host "   ✓ Soluções:" -ForegroundColor Green
                Write-Host "       1. Validar nomes dos DCs: nslookup $($DCs[0])" -ForegroundColor Green
                Write-Host "       2. Verificar DNS local: Get-DnsClientServerAddress" -ForegroundColor Green
                Write-Host "       3. Usar FQDN ou IP do DC" -ForegroundColor Green
            }
            else {
                Write-Host "   💡 Diagnóstico: Erro não categorizado - verifique WinRM e conectividade" -ForegroundColor Cyan
            }
            
            Write-Host ""
            Write-Host "🔄 Erro de PSRemoting – o monitor continuará tentando nos DCs a cada ciclo..." -ForegroundColor Yellow
            Write-Host ""
            if ($failureCount -ge 3) {
                Write-Host "🚫 Três tentativas falharam, encerrando monitoramento." -ForegroundColor Red
                break
            }
        }
        # intervalo entre tentativas
        Start-Sleep -Seconds 10
    }
}

# ============== VERIFICAÇÃO DE PRÉ-REQUISITOS ==============
function Test-PSRemotingAvailability {
    param([string[]]$ComputerNames)
    
    $disponivel = $true
    $resultados = @()
    
    foreach ($dc in $ComputerNames) {
        try {
            Write-Host "  🔍 Testando PSRemoting em: $dc..." -ForegroundColor Cyan -NoNewline
            Test-WSMan -ComputerName $dc -ErrorAction Stop | Out-Null
            Write-Host " ✅" -ForegroundColor Green
            $resultados += @{ DC = $dc; Status = "OK"; Erro = $null }
        }
        catch {
            $errorMsg = $_.Exception.Message
            $errorCode = $_.Exception.HResult
            $errorType = $_.Exception.GetType().Name
            
            Write-Host " ❌" -ForegroundColor Red
            Write-Host "     └─ Tipo: $errorType" -ForegroundColor Yellow
            Write-Host "     └─ Código: 0x$($errorCode.ToString('X8'))" -ForegroundColor Yellow
            Write-Host "     └─ Mensagem: $errorMsg" -ForegroundColor Yellow
            
            # Diagnóstico específico
            if ($errorMsg -match "timeout|timed out|WinRM") {
                Write-Host "     └─ 💡 Causa provável: Timeout de conexão ou WinRM desabilitado" -ForegroundColor DarkYellow
            }
            elseif ($errorMsg -match "Access Denied|Acesso Negado|Unauthorized") {
                Write-Host "     └─ 💡 Causa provável: Credenciais insuficientes ou lista de confiança" -ForegroundColor DarkYellow
            }
            elseif ($errorMsg -match "not found|não resolvido|resolver") {
                Write-Host "     └─ 💡 Causa provável: Nome do DC inválido ou problema de DNS" -ForegroundColor DarkYellow
            }
            elseif ($errorMsg -match "firewall|porta|port") {
                Write-Host "     └─ 💡 Causa provável: Firewall bloqueando porta 5985/5986" -ForegroundColor DarkYellow
            }
            
            $resultados += @{ DC = $dc; Status = "FALHA"; Erro = $errorMsg; ErrorCode = $errorCode; ErrorType = $errorType }
            $disponivel = $false
        }
    }
    
    return @{ Disponivel = $disponivel; Detalhes = $resultados }
}

function Show-PSRemotingDiagnostics {
    param([string[]]$ComputerNames)
    
    Clear-Host
    Write-Host "╔═════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              🔍 DIAGNÓSTICO COMPLETO DE PSRemoting              ║" -ForegroundColor Cyan
    Write-Host "╚═════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "1️⃣  Verificando WinRM localmente..." -ForegroundColor Yellow
    try {
        $winrmStatus = Get-Service -Name WinRM
        Write-Host "   ✅ Serviço WinRM encontrado: $($winrmStatus.Status)" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ WinRM não encontrado ou inacessível" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "2️⃣  Testando conectividade WSMan nos DCs..." -ForegroundColor Yellow
    foreach ($dc in $ComputerNames) {
        try {
            $wsmanTest = Test-WSMan -ComputerName $dc -ErrorAction SilentlyContinue
            if ($wsmanTest) {
                Write-Host "   ✅ $dc - PSRemoting ATIVO" -ForegroundColor Green
            }
        } catch {
            Write-Host "   ❌ $dc - PSRemoting INATIVO ou INACESSÍVEL" -ForegroundColor Red
            
            # Tenta diagnóstico adicional
            Write-Host "      🔧 Tentando diagnóstico avançado..." -ForegroundColor Gray
            try {
                $winrmConfig = Invoke-Command -ComputerName $dc -ScriptBlock { 
                    Get-Service WinRM | Select-Object Status 
                } -ErrorAction SilentlyContinue -OperationTimeoutSec 3
                Write-Host "      └─ WinRM Status: $($winrmConfig.Status)" -ForegroundColor Yellow
            } catch {
                Write-Host "      └─ Não foi possível se conectar para diagnóstico" -ForegroundColor DarkRed
            }
        }
    }
    
    Write-Host ""
    Write-Host "3️⃣  Verificando Trusted Hosts..." -ForegroundColor Yellow
    try {
        $trustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
        if ($trustedHosts.Value) {
            Write-Host "   ✅ Trusted Hosts configurados: $($trustedHosts.Value)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Trusted Hosts vazio - aceita todos os hosts" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ⚠️  Erro ao ler Trusted Hosts" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "4️⃣  Testando portas WSMan (5985/5986)..." -ForegroundColor Yellow
    foreach ($dc in $ComputerNames) {
        $portaHttp = Test-NetConnection -ComputerName $dc -Port 5985 -InformationLevel Quiet -ErrorAction SilentlyContinue
        $portaHttps = Test-NetConnection -ComputerName $dc -Port 5986 -InformationLevel Quiet -ErrorAction SilentlyContinue
        
        if ($portaHttp -or $portaHttps) {
            Write-Host "   ✅ $dc - Portas acessíveis" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $dc - Portas NÃO acessíveis (firewall pode estar bloqueando)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "5️⃣  Informações do Sistema Local..." -ForegroundColor Yellow
    $osInfo = [System.Environment]::OSVersion
    Write-Host "   • SO: $($osInfo.VersionString)" -ForegroundColor Gray
    $psInfo = $PSVersionTable.PSVersion
    Write-Host "   • PowerShell: $($psInfo.Major).$($psInfo.Minor)" -ForegroundColor Gray
    Write-Host ""
}

function Show-PSRemotingInstructions {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║         ⚠️  PSRemoting NÃO HABILITADO NOS DOMAIN CONTROLLERS   ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para usar este script COM conexão remota aos DCs, execute:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  📝 EM CADA DOMAIN CONTROLLER (como Administrador):" -ForegroundColor Cyan
    Write-Host "  " -ForegroundColor Green
    Write-Host "  Enable-PSRemoting -Force -SkipNetworkProfileCheck" -ForegroundColor Green
    Write-Host ""
    Write-Host "  🔄 OU REMOTAMENTE (de um DC para todos os outros):" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  `$DCs = @('SSOOAD01', 'SSOOAD02')  # Altere conforme necessário" -ForegroundColor Green
    Write-Host "  `$DCs | ForEach-Object {" -ForegroundColor Green
    Write-Host "      Invoke-Command -ComputerName `$_ -ScriptBlock {" -ForegroundColor Green
    Write-Host "          Enable-PSRemoting -Force -SkipNetworkProfileCheck" -ForegroundColor Green
    Write-Host "      }" -ForegroundColor Green
    Write-Host "  }" -ForegroundColor Green
    Write-Host ""
    Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "Opções disponíveis:" -ForegroundColor Yellow
    Write-Host "1) Executar Diagnóstico Completo de PSRemoting" -ForegroundColor Cyan
    Write-Host "2) Habilitar PSRemoting automaticamente AGORA (requer admin)" -ForegroundColor Cyan
    Write-Host "3) Sair" -ForegroundColor Gray
    Write-Host ""
    
    $opcao = Read-Host "Escolha (1, 2 ou 3)"
    return $opcao
}

function Enable-PSRemotingOnDCs {
    param([string[]]$ComputerNames)
    
    Write-Host ""
    Write-Host "🔄 Habilitando PSRemoting nos DCs..." -ForegroundColor Green
    
    foreach ($dc in $ComputerNames) {
        try {
            Write-Host "  ⏳ Processando: $dc..." -ForegroundColor Yellow -NoNewline
            Invoke-Command -ComputerName $dc -ScriptBlock {
                Enable-PSRemoting -Force -SkipNetworkProfileCheck
            } -ErrorAction Stop | Out-Null
            Write-Host " ✅" -ForegroundColor Green
        }
        catch {
            Write-Host " ❌ Falha: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "✅ Processo concluído! Reiniciando..." -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# ============== EXECUÇÃO PRINCIPAL ==============
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "⚠️  Este script requer privilégios de ADMINISTRADOR." -ForegroundColor Yellow
        Write-Host "    Reinicie o PowerShell como Administrador." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        exit
    }

    # Verifica se PSRemoting está disponível
    Write-Host "🔐 Verificando disponibilidade de PSRemoting..." -ForegroundColor Cyan
    $testRemoting = Test-PSRemotingAvailability -ComputerNames $DCs
    
    if (-not $testRemoting.Disponivel) {
        Write-Host ""
        Write-Host "⚠️  Alguns DCs não responderam a PSRemoting. O monitor fará tentativas contínuas." -ForegroundColor Yellow
        foreach ($resultado in $testRemoting.Detalhes | Where-Object { $_.Status -eq "FALHA" }) {
            Write-Host "  • $($resultado.DC): $($resultado.Erro)" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    $choice = Get-MonitoringChoice
    Start-ADLockoutMonitor -MonitoringChoice $choice
}
catch {
    Write-Host "Erro crítico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    Write-Host "Pressione Enter para sair..." -ForegroundColor Yellow
    Read-Host
}