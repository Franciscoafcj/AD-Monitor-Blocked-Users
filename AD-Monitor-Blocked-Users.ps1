<#Nome:  AD-Monitor-Blocked-Users.ps1
 Função: Monitora bloqueios de conta em tempo real nos controladores de domínio
 OBS: Rodar com nível elevado
 Versão: 1.0#>



# Configuração
$LogName = "Security"
$EventID = 4740  # Evento de conta bloqueada no AD
$DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name
$RefreshInterval = 5  # Segundos entre verificações

# ============== ESCOLHA DE MONITORAMENTO ==============
function Get-MonitoringChoice {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       MONITOR DE BLOQUEIOS - ACTIVE DIRECTORY   ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║ Selecione o tipo de monitoramento:              ║" -ForegroundColor White
    Write-Host "║                                                ║"
    Write-Host "║ 1) Monitorar TODOS os usuários                 ║" -ForegroundColor Yellow
    Write-Host "║ 2) Monitorar um USUÁRIO ESPECÍFICO             ║" -ForegroundColor Green
    Write-Host "║                                                ║"
    Write-Host "║ Pressione 1 ou 2...                           ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $choice = $null
    while ($choice -notin @('1', '2')) {
        $choice = Read-Host "Digite sua opção (1 ou 2)"
        
        if ($choice -eq '2') {
            $usuario = Read-Host "Digite o nome do usuário para monitorar (ex: dma.8)"
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

# ============== FUNÇÃO ORIGINAL (SEM ALTERAÇÕES) ==============
function Format-LockoutEvent {
    param($Event)
    
    $TimeCreated = $Event.TimeCreated
    $Message = $Event.Message
    $TargetUserName = ($Event.Properties[0].Value)
    $CallerComputer = ($Event.Properties[1].Value)
    $CallerUserName = ($Event.Properties[5].Value)
    
    # Formatar saída colorida
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "🚨 BLOQUEIO DETECTADO" -ForegroundColor Yellow -BackgroundColor DarkRed
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Usuário: $TargetUserName" -ForegroundColor Cyan
    Write-Host "Data/Hora: $TimeCreated" -ForegroundColor White
    Write-Host "Computador de origem: $CallerComputer" -ForegroundColor Magenta
    Write-Host "----------------------------------------" -ForegroundColor Gray
}

# ============== MONITORAMENTO ==============
function Start-ADLockoutMonitor {
    param($MonitoringChoice)
    
    $MonitorEspecifico = ($MonitoringChoice.Tipo -eq "Especifico")
    $UsuarioAlvo = $MonitoringChoice.Usuario
    
    Clear-Host
    
    if ($MonitorEspecifico) {
        Write-Host "🔍 MONITOR DE BLOQUEIOS - USUÁRIO ESPECÍFICO" -ForegroundColor Green
        Write-Host "Usuário monitorado: $UsuarioAlvo" -ForegroundColor Yellow
    } else {
        Write-Host "🔍 MONITOR DE BLOQUEIOS - ACTIVE DIRECTORY" -ForegroundColor Green
    }
    
    Write-Host "Iniciando monitoramento em: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor White
    Write-Host "DCS: $($DCs -join ', ')" -ForegroundColor Cyan
    Write-Host "Pressione Ctrl+C para sair" -ForegroundColor Yellow
    Write-Host ""
    
    $lastChecked = [DateTime]::MinValue
    $contadorEspecifico = 0
    
    while ($true) {
        foreach ($DC in $DCs) {
            try {
                # Buscar eventos de bloqueio desde a última verificação
                $events = Get-WinEvent -ComputerName $DC -FilterHashtable @{
                    LogName = $LogName
                    ID = $EventID
                    StartTime = $lastChecked
                } -ErrorAction SilentlyContinue
                
                if ($events) {
                    foreach ($event in $events) {
                        $userName = $event.Properties[0].Value
                        
                        if ($MonitorEspecifico) {
                            # Mostrar apenas se for o usuário específico
                            if ($userName -eq $UsuarioAlvo) {
                                $contadorEspecifico++
                                Format-LockoutEvent -Event $event
                                Write-Host "[BLOQUEIO $contadorEspecifico para $UsuarioAlvo]" -ForegroundColor Gray
                                Write-Host ""
                            }
                        } else {
                            # Mostrar todos
                            Format-LockoutEvent -Event $event
                        }
                    }
                }
            }
            catch {
                Write-Host "[$DC] Erro: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        $lastChecked = Get-Date
        Start-Sleep -Seconds $RefreshInterval
    }
}

# ============== EXECUÇÃO PRINCIPAL ==============
try {
    # Pedir ao usuário para escolher o tipo de monitoramento
    $choice = Get-MonitoringChoice
    
    # Iniciar monitoramento com a escolha do usuário
    Start-ADLockoutMonitor -MonitoringChoice $choice
}
catch {
    Write-Host "Erro: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}