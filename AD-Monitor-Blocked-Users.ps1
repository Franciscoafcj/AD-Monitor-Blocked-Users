# ============== CONFIGURAÇÕES INICIAIS ==============
if (-not (Get-Module -Name ActiveDirectory)) {
    Import-Module ActiveDirectory -ErrorAction Stop
}

$LogName = "Security"
$EventID = 4740  # Evento de conta bloqueada no AD
$DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name
$RefreshInterval = 5  # Segundos entre verificações

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

    $ip = $cacheDns[$CallerComputer] ? $cacheDns[$CallerComputer] : "Não resolvido"

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
        $Event,
        $TargetUserName,
        $CallerComputer
    )
    
    $TimeCreated = $Event.TimeCreated
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
function Start-ADLockoutMonitor {
    param($MonitoringChoice, [bool]$UseRemote = $true)
    
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
    if ($UseRemote) {
        Write-Host "Servidores DC: $($DCs -join ', ')" -ForegroundColor Cyan
        Write-Host "Modo: Remoto (PSRemoting) 🌐" -ForegroundColor Cyan
    } else {
        Write-Host "Modo: Local (Este servidor apenas) 🖥️" -ForegroundColor Yellow
    }
    Write-Host "Motor de Busca: Paralelo (Alta Velocidade) ⚡" -ForegroundColor DarkYellow
    Write-Host "Pressione Ctrl+C para sair`n" -ForegroundColor Yellow
    Write-Host "✅ Monitoramento ativo - aguardando bloqueios..." -ForegroundColor Green
    Write-Host "" 
    
    $lastChecked = (Get-Date).AddMinutes(-5)
    $contadorEspecifico = 0
    $processedEvents = [System.Collections.Generic.HashSet[string]]::new()
    $cicloContagem = 0
    
    while ($true) {
        $cicloContagem++
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Ciclo #$cicloContagem - Verificando eventos..." -ForegroundColor Gray -NoNewline
        $currentCheckTime = Get-Date
        
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
        
        if ($UseRemote) {
            try {
                # Executa o bloco de código em TODOS os DCs ao mesmo tempo usando PSRemoting
                $resultados = Invoke-Command -ComputerName $DCs -ScriptBlock $ScriptBloco -ErrorAction Stop
                
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
            }
            catch {
                Write-Host " ❌ (PSRemoting falhou - alternando para LOCAL)" -ForegroundColor Red
                Write-Host ""
                $UseRemote = $false  # Alterna para local
            }
        }
        
        if (-not $UseRemote) {
            # Busca LOCAL
            try {
                $eventos = Get-WinEvent -FilterHashtable @{ 
                    LogName   = 'Security'
                    ID        = 4740
                    StartTime = $lastChecked
                } -ErrorAction SilentlyContinue
                
                if ($eventos) {
                    foreach ($evt in $eventos) {
                        $props = @{}
                        for ($i = 0; $i -lt $evt.Properties.Count; $i++) {
                            if ($i -eq 0) { $props['TargetUserName'] = $evt.Properties[$i].Value }
                            if ($i -eq 3) { $props['CallerComputer'] = $evt.Properties[$i].Value }
                        }
                        
                        $uniqueEventId = "LOCAL-$($evt.RecordId)"
                        if ($processedEvents.Add($uniqueEventId)) {
                            $userName = $props['TargetUserName']
                            $callerComputer = $props['CallerComputer']
                            
                            if ($MonitorEspecifico) {
                                if ($userName -ieq $UsuarioAlvo) {
                                    $contadorEspecifico++
                                    Write-Host "`n[OCORRÊNCIA #$contadorEspecifico PARA $UsuarioAlvo]" -ForegroundColor DarkYellow
                                    Format-LockoutEvent -Event $evt -TargetUserName $userName -CallerComputer $callerComputer
                                }
                            } else {
                                Write-Host "`n[OCORRÊNCIA REGISTRADA]" -ForegroundColor DarkGray
                                Format-LockoutEvent -Event $evt -TargetUserName $userName -CallerComputer $callerComputer
                            }
                        }
                    }
                }
            }
            catch {
                Write-Host " ❌" -ForegroundColor Red
                Write-Host "Erro ao buscar eventos: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        if ($UseRemote) {
            Write-Host " ✅" -ForegroundColor Green
        } elseif ($cicloContagem -eq 1) {
            Write-Host ""  # Quebra de linha já feita acima no modo local
        }
        
    }
}

# ============== VERIFICAÇÃO DE PRÉ-REQUISITOS ==============
function Test-PSRemotingAvailability {
    param([string[]]$ComputerNames)
    
    $disponivel = $true
    foreach ($dc in $ComputerNames) {
        try {
            Test-WSMan -ComputerName $dc -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Host "❌ PSRemoting NÃO está habilitado em: $dc" -ForegroundColor Red
            $disponivel = $false
        }
    }
    return $disponivel
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
    Write-Host "1) Habilitar PSRemoting automaticamente AGORA (requer admin)" -ForegroundColor Cyan
    Write-Host "2) Continuar com busca LOCAL apenas (sem acesso remoto aos DCs)" -ForegroundColor Cyan
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
            $resultado = Invoke-Command -ComputerName $dc -ScriptBlock {
                Enable-PSRemoting -Force -SkipNetworkProfileCheck
            } -ErrorAction Stop
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
    if (-not (Test-PSRemotingAvailability -ComputerNames $DCs)) {
        $opcaoRemoting = Show-PSRemotingInstructions
        
        switch ($opcaoRemoting) {
            "1" {
                Write-Host ""
                Write-Host "🔐 Você já deve estar em um DC ou ter conectividade remota." -ForegroundColor Yellow
                Write-Host "   Tentando habilitar PSRemoting nos DCs..." -ForegroundColor Yellow
                Write-Host ""
                Enable-PSRemotingOnDCs -ComputerNames $DCs
                & $MyInvocation.MyCommand.Path  # Reinicia o script
                return
            }
            "2" {
                Write-Host ""
                Write-Host "⚠️  Continuando com busca LOCAL apenas." -ForegroundColor Yellow
                Write-Host "   (Eventos remotos dos DCs NÃO serão capturados)" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
            "3" {
                Write-Host "Saindo..." -ForegroundColor Gray
                exit
            }
            default {
                Write-Host "Opção inválida. Saindo..." -ForegroundColor Red
                exit
            }
        }
    }

    $choice = Get-MonitoringChoice
    $useRemote = Test-PSRemotingAvailability -ComputerNames $DCs
    Start-ADLockoutMonitor -MonitoringChoice $choice -UseRemote $useRemote
}
catch {
    Write-Host "Erro crítico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    Write-Host "Pressione Enter para sair..." -ForegroundColor Yellow
    Read-Host
}