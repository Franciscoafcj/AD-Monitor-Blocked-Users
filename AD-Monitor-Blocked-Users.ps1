# ============== CONFIGURAÇÕES INICIAIS ==============
$LogName = "Security"
$EventID = 4740  # Evento de conta bloqueada no AD
$DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name
$RefreshInterval = 5  # Segundos entre verificações

# ============== ESCOLHA DE MONITORAMENTO ==============
function Get-MonitoringChoice {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       MONITOR DE BLOQUEIOS - ACTIVE DIRECTORY    ║" -ForegroundColor Cyan
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

    # Se o computador de origem vier em branco
    if ([string]::IsNullOrWhiteSpace($CallerComputer) -or $CallerComputer -eq "-") {
        return @{
            IP = "N/A"
            Suspeita = "Origem Oculta. Causas comuns: Celular via ActiveSync/Exchange, Autenticação RADIUS/NPS (Wi-Fi), ou mapeamento de rede antigo em máquina fora do domínio."
        }
    }

    $ip = "Não resolvido"
    try {
        # Tenta resolver o IP do dispositivo de origem
        $dns = Resolve-DnsName -Name $CallerComputer -Type A -ErrorAction SilentlyContinue
        if ($dns) { $ip = $dns.IPAddress[0] }
    } catch {}

    # Analisa o nome para sugerir a causa (Variações)
    $suspeita = "Estação de Trabalho / Dispositivo Padrão. (Verifique Gerenciador de Credenciais do Windows ou Tarefas Agendadas neste IP)."
    
    if ($CallerComputer -match "(?i)EXCH|MAIL|OWA|WEB") {
        $suspeita = "Servidor de E-mail/Web. 📱 Forte indício de celular com senha desatualizada tentando sincronizar e-mail."
    } elseif ($CallerComputer -match "(?i)DC0|AD0|SRV-AD") {
        $suspeita = "Domain Controller. 🔄 O bloqueio ocorreu via autenticação direta no DC. Verifique Wi-Fi (NPS), VPN ou scripts de logon."
    } elseif ($CallerComputer -match "(?i)VPN|FW|FIREWALL") {
        $suspeita = "Gateway/VPN. 🌍 Tentativa de conexão externa com credencial salva ou ataque de força bruta externo."
    } elseif ($CallerComputer -match "(?i)FS|FILE|ARQUIVO") {
        $suspeita = "File Server. 📁 Há um mapeamento de rede antigo usando as credenciais deste usuário."
    }

    return @{
        IP = $ip
        Suspeita = $suspeita
    }
}

# ============== FORMATAÇÃO DA SAÍDA ==============
function Format-LockoutEvent {
    param($Event)
    
    $TimeCreated = $Event.TimeCreated
    
    # Extração segura das propriedades do Evento 4740
    $TargetUserName = $Event.Properties[0].Value
    $CallerComputer = $Event.Properties[1].Value
    
    # Chama a função de análise de origem
    $Analysis = Get-SourceAnalysis -CallerComputer $CallerComputer

    # Formatar saída colorida
    Write-Host "`n==================================================" -ForegroundColor Red
    Write-Host " 🚨 BLOQUEIO DETECTADO " -ForegroundColor Yellow -BackgroundColor DarkRed
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "👤 Usuário:        $TargetUserName" -ForegroundColor Cyan
    Write-Host "🕒 Data/Hora:      $TimeCreated" -ForegroundColor White
    Write-Host "💻 Disp. de Origem: $($CallerComputer ? $CallerComputer : 'Desconhecido/Oculto')" -ForegroundColor Magenta
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
    Write-Host "Pressione Ctrl+C para sair`n" -ForegroundColor Yellow
    
    # Ajuste crítico: Começa a buscar eventos dos últimos 5 minutos, evitando ler o histórico inteiro do AD.
    $lastChecked = (Get-Date).AddMinutes(-5)
    $contadorEspecifico = 0
    
    while ($true) {
        foreach ($DC in $DCs) {
            try {
                $events = Get-WinEvent -ComputerName $DC -FilterHashtable @{
                    LogName = $LogName
                    ID = $EventID
                    StartTime = $lastChecked
                } -ErrorAction SilentlyContinue
                
                if ($events) {
                    # Inverte a ordem para mostrar os mais antigos primeiro (ordem cronológica)
                    [array]::Reverse($events)

                    foreach ($event in $events) {
                        $userName = $event.Properties[0].Value
                        
                        if ($MonitorEspecifico) {
                            if ($userName -eq $UsuarioAlvo) {
                                $contadorEspecifico++
                                Write-Host "[OCORRÊNCIA #$contadorEspecifico PARA $UsuarioAlvo]" -ForegroundColor DarkYellow
                                Format-LockoutEvent -Event $event
                            }
                        } else {
                            Format-LockoutEvent -Event $event
                        }
                    }
                }
            }
            catch {
                Write-Host "[$DC] Falha ao consultar: $($_.Exception.Message)" -ForegroundColor DarkRed
            }
        }
        
        $lastChecked = Get-Date
        Start-Sleep -Seconds $RefreshInterval
    }
}

# ============== EXECUÇÃO PRINCIPAL ==============
try {
    # Necessário rodar como Administrador para consultar logs remotos
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Aviso: Recomenda-se rodar este script como Administrador para ter permissão de ler os logs dos DCs." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }

    $choice = Get-MonitoringChoice
    Start-ADLockoutMonitor -MonitoringChoice $choice
}
catch {
    Write-Host "Erro crítico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}