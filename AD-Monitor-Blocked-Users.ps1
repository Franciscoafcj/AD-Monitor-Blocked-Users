# ============== CONFIGURAÇÕES INICIAIS ==============
if (-not (Get-Module -Name ActiveDirectory)) {
    Import-Module ActiveDirectory -ErrorAction Stop
}

$LogName = "Security"
$EventID = 4740  # Evento de conta bloqueada no AD
$DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name
$RefreshInterval = 5  # Segundos entre verificações

# ============== ESCOLHA DE MONITORAMENTO ==============
function Get-MonitoringChoice {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        MONITOR DE BLOQUEIOS - ACTIVE DIRECTORY   ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║ Selecione o tipo de monitoramento:               ║" -ForegroundColor White
    Write-Host "║                                                  ║"
    Write-Host "║ 1) Monitorar TODOS os usuários                 ║" -ForegroundColor Yellow
    Write-Host "║ 2) Monitorar um USUÁRIO ESPECÍFICO             ║" -ForegroundColor Green
    Write-Host "║                                                  ║"
    Write-Host "║ Pressione 1 ou 2...                            ║" -ForegroundColor White
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

    $ip = "Não resolvido"
    try {
        $dns = Resolve-DnsName -Name $CallerComputer -Type A -ErrorAction SilentlyContinue
        if ($dns) { $ip = $dns.IPAddress[0] }
    } catch {}

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
    Write-Host "Motor de Busca: Paralelo (Alta Velocidade) ⚡" -ForegroundColor DarkYellow
    Write-Host "Pressione Ctrl+C para sair`n" -ForegroundColor Yellow
    
    $lastChecked = (Get-Date).AddMinutes(-5)
    $contadorEspecifico = 0
    $processedEvents = [System.Collections.Generic.HashSet[string]]::new()
    
    while ($true) {
        $currentCheckTime = Get-Date 
        
        # O ScriptBlock que será enviado e executado dentro de todos os DCs simultaneamente
        $ScriptBloco = {
            $threshold = $using:lastChecked
            $eventos = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; ID = 4740 } -MaxEvents 50 -ErrorAction SilentlyContinue
            
            if ($eventos) {
                # Filtra o tempo e faz a extração do XML DENTRO do servidor remoto (muito mais rápido)
                $filtrados = $eventos | Where-Object { $_.TimeCreated -ge $threshold }
                
                foreach ($evt in $filtrados) {
                    $xml = [xml]$evt.ToXml()
                    $dados = $xml.Event.EventData.Data
                    
                    # Retorna um objeto leve para a sua máquina
                    [PSCustomObject]@{
                        RecordId       = $evt.RecordId
                        TimeCreated    = $evt.TimeCreated
                        TargetUserName = ($dados | Where-Object Name -eq 'TargetUserName').'#text'
                        CallerComputer = ($dados | Where-Object Name -eq 'CallerComputer').'#text'
                        OrigemDC       = $env:COMPUTERNAME
                    }
                }
            }
        }

        try {
            # Executa o bloco de código em TODOS os DCs ao mesmo tempo usando PSRemoting
            $resultados = Invoke-Command -ComputerName $DCs -ScriptBlock $ScriptBloco -ErrorAction SilentlyContinue
            
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
                            if ($userName -match $UsuarioAlvo) {
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
            # Ignora erros de rede momentâneos na thread paralela
        }
        
        $lastChecked = $currentCheckTime
        Start-Sleep -Seconds $RefreshInterval
    }
}

# ============== EXECUÇÃO PRINCIPAL ==============
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Aviso: Recomenda-se fortemente rodar este script como Administrador para ter permissão de ler logs remotos." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }

    $choice = Get-MonitoringChoice
    Start-ADLockoutMonitor -MonitoringChoice $choice
}
catch {
    Write-Host "Erro crítico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Pressione Enter para sair..." -ForegroundColor Yellow
    Read-Host
}