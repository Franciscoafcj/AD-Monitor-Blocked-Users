# ============================================================
#  AD LOCKOUT MONITOR v2.0
#  Requer: PowerShell 5.1+, Módulo ActiveDirectory, Admin
# ============================================================

#region ── INICIALIZAÇÃO ────────────────────────────────────

if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
    Import-Module ActiveDirectory -ErrorAction Stop
}

$DCs      = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name
$cacheDns = @{}

# Estatísticas globais da sessão
$script:Stats = @{
    TotalBloqueios  = 0
    UltimaHora      = [System.Collections.Generic.Queue[datetime]]::new()
    BloqueiosPorDC  = @{}
    BloqueiosPorUser= @{}
    CicloAtual      = 0
    Inicio          = Get-Date
}
foreach ($dc in $DCs) { $script:Stats.BloqueiosPorDC[$dc] = 0 }

#endregion

#region ── HELPERS DE INTERFACE ─────────────────────────────

function Write-Separator {
    param(
        [string]$Char  = '─',
        [int]   $Width = 72,
        [System.ConsoleColor]$Color = 'DarkGray'
    )
    Write-Host ($Char * $Width) -ForegroundColor $Color
}

function Write-Header {
    param([string]$Title, [string]$Subtitle = '')
    $width = 72
    Write-Host ''
    Write-Host ('╔' + ('═' * ($width - 2)) + '╗') -ForegroundColor Cyan
    $pad = [math]::Floor(($width - 2 - $Title.Length) / 2)
    $line = '║' + (' ' * $pad) + $Title + (' ' * ($width - 2 - $pad - $Title.Length)) + '║'
    Write-Host $line -ForegroundColor Cyan
    if ($Subtitle) {
        $pad2 = [math]::Floor(($width - 2 - $Subtitle.Length) / 2)
        $line2 = '║' + (' ' * $pad2) + $Subtitle + (' ' * ($width - 2 - $pad2 - $Subtitle.Length)) + '║'
        Write-Host $line2 -ForegroundColor DarkCyan
    }
    Write-Host ('╚' + ('═' * ($width - 2)) + '╝') -ForegroundColor Cyan
    Write-Host ''
}

function Write-StatusBar {
    param([string]$Message, [System.ConsoleColor]$Color = 'DarkGray')
    $ts = Get-Date -Format 'HH:mm:ss'
    Write-Host "  [$ts] " -ForegroundColor DarkGray -NoNewline
    Write-Host $Message -ForegroundColor $Color
}

function Write-KeyValue {
    param(
        [string]$Key,
        [string]$Value,
        [System.ConsoleColor]$KeyColor   = 'DarkGray',
        [System.ConsoleColor]$ValueColor = 'White',
        [int]$KeyWidth = 22
    )
    Write-Host ("  {0,-$KeyWidth}" -f "$Key") -ForegroundColor $KeyColor -NoNewline
    Write-Host $Value -ForegroundColor $ValueColor
}

function Write-Badge {
    param(
        [string]$Text,
        [System.ConsoleColor]$BgColor   = 'DarkRed',
        [System.ConsoleColor]$TextColor = 'White'
    )
    Write-Host " $Text " -ForegroundColor $TextColor -BackgroundColor $BgColor -NoNewline
    Write-Host ''
}

#endregion

#region ── ANÁLISE DE ORIGEM ────────────────────────────────

function Get-SourceAnalysis {
    param([string]$CallerComputer)

    if ([string]::IsNullOrWhiteSpace($CallerComputer) -or $CallerComputer -eq '-') {
        return @{
            IP       = 'N/A'
            Icone    = '[?]'
            Tipo     = 'Origem Oculta'
            Suspeita = 'Celular via ActiveSync/Exchange, RADIUS/NPS (Wi-Fi) ou mapeamento fora do domínio.'
            Sev      = 'Med'
        }
    }

    if (-not $cacheDns.ContainsKey($CallerComputer)) {
        try   { $cacheDns[$CallerComputer] = (Resolve-DnsName -Name $CallerComputer -Type A -EA SilentlyContinue).IPAddress | Select-Object -First 1 }
        catch { $cacheDns[$CallerComputer] = $null }
    }
    $ip = if ($cacheDns[$CallerComputer]) { $cacheDns[$CallerComputer] } else { 'Não resolvido' }

    $result = switch -Regex ($CallerComputer) {
        '(?i)EXCH|MAIL|OWA|WEB' { @{ Icone='[M]'; Tipo='Servidor E-mail/Web';  Suspeita='Celular com senha desatualizada (ActiveSync).';                 Sev='Med'  }; break }
        '(?i)DC0|AD0|SRV-AD'    { @{ Icone='[D]'; Tipo='Domain Controller';    Suspeita='Autenticação direta. Verifique Wi-Fi (NPS), VPN ou scripts.';  Sev='Med'  }; break }
        '(?i)VPN|FW|FIREWALL'   { @{ Icone='[!]'; Tipo='Gateway / VPN';        Suspeita='Tentativa de conexão externa. Possível ataque de força bruta.'; Sev='High' }; break }
        '(?i)FS|FILE|ARQUIVO'   { @{ Icone='[F]'; Tipo='File Server';          Suspeita='Mapeamento de rede antigo usando credenciais do usuário.';      Sev='Low'  }; break }
        default                  { @{ Icone='[W]'; Tipo='Estação de Trabalho';  Suspeita='Verifique Gerenciador de Credenciais ou Tarefas Agendadas.';    Sev='Low'  } }
    }
    $result['IP'] = $ip
    return $result
}

#endregion

#region ── FORMATAÇÃO DE EVENTOS ────────────────────────────

function Format-LockoutEvent {
    param($Evento, [string]$TargetUserName, [string]$CallerComputer, [string]$DCNome)

    $analysis   = Get-SourceAnalysis -CallerComputer $CallerComputer
    $timestamp  = $Evento.TimeCreated
    $compDisplay = if ([string]::IsNullOrWhiteSpace($CallerComputer) -or $CallerComputer -eq '-') { 'Desconhecido / Oculto' } else { $CallerComputer }

    # ── cabeçalho do alerta ──────────────────────────────────
    Write-Host ''
    Write-Separator -Char '═' -Color Red
    Write-Host '  ' -NoNewline
    switch ($analysis.Sev) {
        'High' { Write-Badge -Text ' BLOQUEIO CRÍTICO ' -BgColor DarkRed    -TextColor White }
        'Med'  { Write-Badge -Text ' BLOQUEIO DETECTADO' -BgColor DarkYellow -TextColor Black }
        'Low'  { Write-Badge -Text ' BLOQUEIO REGISTRADO' -BgColor DarkBlue  -TextColor White }
    }
    Write-Separator -Char '─' -Color DarkGray

    # ── campos principais ────────────────────────────────────
    Write-KeyValue -Key 'Usuário'          -Value $TargetUserName    -ValueColor Cyan
    Write-KeyValue -Key 'Data / Hora'      -Value ($timestamp.ToString('dd/MM/yyyy  HH:mm:ss')) -ValueColor White
    Write-KeyValue -Key 'Domain Controller'-Value $DCNome            -ValueColor DarkCyan
    Write-Separator -Char '·' -Width 72 -Color DarkGray
    Write-KeyValue -Key 'Disp. de Origem'  -Value "$($analysis.Icone) $compDisplay"  -ValueColor Magenta
    Write-KeyValue -Key 'Tipo de Origem'   -Value $analysis.Tipo     -ValueColor DarkMagenta
    Write-KeyValue -Key 'IP Resolvido'     -Value $analysis.IP       -ValueColor DarkMagenta
    Write-Separator -Char '·' -Width 72 -Color DarkGray

    # ── diagnóstico ──────────────────────────────────────────
    Write-Host '  Diagnóstico    ' -ForegroundColor DarkGray -NoNewline
    switch ($analysis.Sev) {
        'High' { Write-Host $analysis.Suspeita -ForegroundColor Red    }
        'Med'  { Write-Host $analysis.Suspeita -ForegroundColor Yellow }
        'Low'  { Write-Host $analysis.Suspeita -ForegroundColor Green  }
    }
    Write-Separator -Char '═' -Color Red
}

#endregion

#region ── PAINEL DE ESTATÍSTICAS ───────────────────────────

function Show-StatsPanel {
    $uptime    = (Get-Date) - $script:Stats.Inicio
    $uptimeStr = '{0:D2}h {1:D2}m {2:D2}s' -f [int]$uptime.TotalHours, $uptime.Minutes, $uptime.Seconds

    # limpa fila de "última hora"
    while ($script:Stats.UltimaHora.Count -gt 0 -and ((Get-Date) - $script:Stats.UltimaHora.Peek()).TotalMinutes -gt 60) {
        $script:Stats.UltimaHora.Dequeue() | Out-Null
    }

    $width = 72
    Write-Host ''
    Write-Host ('┌' + ('─' * ($width - 2)) + '┐') -ForegroundColor DarkCyan

    $title = ' RESUMO DA SESSÃO '
    $pad   = [math]::Floor(($width - 2 - $title.Length) / 2)
    Write-Host ('│' + (' ' * $pad) + $title + (' ' * ($width - 2 - $pad - $title.Length)) + '│') -ForegroundColor DarkCyan

    Write-Host ('├' + ('─' * ($width - 2)) + '┤') -ForegroundColor DarkGray

    function StatLine([string]$k, [string]$v, [System.ConsoleColor]$vc) {
        $line = "│  {0,-24}{1}" -f $k, $v
        $line = $line.PadRight($width - 1) + '│'
        Write-Host '│  ' -ForegroundColor DarkGray -NoNewline
        Write-Host ('{0,-24}' -f $k) -ForegroundColor DarkGray -NoNewline
        Write-Host ('{0}' -f $v).PadRight($width - 28) -ForegroundColor $vc -NoNewline
        Write-Host '│' -ForegroundColor DarkGray
    }

    StatLine 'Tempo de execução:'  $uptimeStr                              'White'
    StatLine 'Ciclos executados:'  $script:Stats.CicloAtual                'Cyan'
    StatLine 'Total de bloqueios:' $script:Stats.TotalBloqueios            'Red'
    StatLine 'Última hora:'        $script:Stats.UltimaHora.Count          'Yellow'
    StatLine 'DCs monitorados:'    ($DCs -join ', ')                        'DarkCyan'

    if ($script:Stats.TotalBloqueios -gt 0) {
        Write-Host ('├' + ('─' * ($width - 2)) + '┤') -ForegroundColor DarkGray
        Write-Host '│  Bloqueios por DC:' -ForegroundColor DarkGray -NoNewline
        Write-Host (' ' * ($width - 21)) -NoNewline
        Write-Host '│' -ForegroundColor DarkGray

        foreach ($dc in $DCs) {
            $cnt = $script:Stats.BloqueiosPorDC[$dc]
            StatLine "    $dc" $cnt 'Magenta'
        }

        # top usuários
        $topUsers = $script:Stats.BloqueiosPorUser.GetEnumerator() |
                    Sort-Object Value -Descending |
                    Select-Object -First 3

        if ($topUsers) {
            Write-Host ('├' + ('─' * ($width - 2)) + '┤') -ForegroundColor DarkGray
            Write-Host '│  Top usuários bloqueados:' -ForegroundColor DarkGray -NoNewline
            Write-Host (' ' * ($width - 28)) -NoNewline
            Write-Host '│' -ForegroundColor DarkGray
            foreach ($u in $topUsers) {
                StatLine "    $($u.Key)" "$($u.Value)x" 'Yellow'
            }
        }
    }

    Write-Host ('└' + ('─' * ($width - 2)) + '┘') -ForegroundColor DarkCyan
    Write-Host ''
}

#endregion

#region ── TELA DE SELEÇÃO ──────────────────────────────────

function Get-MonitoringChoice {
    Clear-Host
    Write-Header -Title 'AD LOCKOUT MONITOR  v2.0' -Subtitle 'Active Directory — Monitor de Bloqueios em Tempo Real'

    Write-Host '  Selecione o tipo de monitoramento:' -ForegroundColor White
    Write-Host ''
    Write-Host '  [1]' -ForegroundColor Yellow -NoNewline
    Write-Host '  Monitorar TODOS os usuários' -ForegroundColor White
    Write-Host ''
    Write-Host '  [2]' -ForegroundColor Green -NoNewline
    Write-Host '  Monitorar um USUÁRIO ESPECÍFICO' -ForegroundColor White
    Write-Host ''
    Write-Separator

    $choice = $null
    while ($choice -notin @('1','2')) {
        Write-Host '  Opção ' -ForegroundColor DarkGray -NoNewline
        $choice = Read-Host

        if ($choice -eq '2') {
            Write-Host ''
            Write-Host '  Usuário (ex: francisco.silva): ' -ForegroundColor DarkGray -NoNewline
            $usuario = Read-Host
            return @{ Tipo = 'Especifico'; Usuario = $usuario }
        }
        elseif ($choice -eq '1') {
            return @{ Tipo = 'Todos'; Usuario = $null }
        }
        else {
            Write-Host '  Opção inválida. Digite 1 ou 2.' -ForegroundColor Red
        }
    }
}

#endregion

#region ── MONITORAMENTO PRINCIPAL ──────────────────────────

function Start-ADLockoutMonitor {
    param($MonitoringChoice)

    $MonitorEspecifico  = ($MonitoringChoice.Tipo -eq 'Especifico')
    $UsuarioAlvo        = $MonitoringChoice.Usuario
    $lastChecked        = (Get-Date).AddDays(-7)
    $processedEvents    = [System.Collections.Generic.HashSet[string]]::new()
    $failureCount       = 0

    Clear-Host
    Write-Header -Title 'AD LOCKOUT MONITOR  v2.0' -Subtitle $(
        if ($MonitorEspecifico) { "Monitorando: $UsuarioAlvo" } else { 'Monitorando todos os usuários' }
    )

    Write-KeyValue -Key 'Início'          -Value (Get-Date -Format 'dd/MM/yyyy HH:mm:ss') -ValueColor White
    Write-KeyValue -Key 'Domain Controllers' -Value ($DCs -join '  |  ')                  -ValueColor Cyan
    Write-KeyValue -Key 'Modo de busca'   -Value 'Remoto via PSRemoting'                  -ValueColor DarkCyan
    Write-KeyValue -Key 'Paralelismo'     -Value 'Todos os DCs simultaneamente'           -ValueColor DarkCyan
    Write-KeyValue -Key 'Intervalo'       -Value '10 segundos por ciclo'                  -ValueColor DarkGray
    Write-Host ''
    Write-Host '  Pressione ' -ForegroundColor DarkGray -NoNewline
    Write-Host 'Ctrl+C' -ForegroundColor Yellow -NoNewline
    Write-Host ' para encerrar.' -ForegroundColor DarkGray
    Write-Separator
    Write-StatusBar 'Monitoramento ativo — aguardando bloqueios...' 'Green'
    Write-Host ''

    $ScriptBloco = {
        $threshold = $using:lastChecked
        $eventos   = Get-WinEvent -FilterHashtable @{
            LogName   = 'Security'
            ID        = 4740
            StartTime = $threshold
        } -ErrorAction SilentlyContinue

        if ($eventos) {
            foreach ($evt in $eventos) {
                [PSCustomObject]@{
                    RecordId       = $evt.RecordId
                    TimeCreated    = $evt.TimeCreated
                    TargetUserName = $evt.Properties[0].Value
                    CallerComputer = $evt.Properties[3].Value
                    OrigemDC       = $env:COMPUTERNAME
                }
            }
        }
    }

    while ($true) {
        $script:Stats.CicloAtual++
        $ciclo = $script:Stats.CicloAtual

        Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] " -ForegroundColor DarkGray -NoNewline
        Write-Host "Ciclo #$ciclo" -ForegroundColor DarkGray -NoNewline
        Write-Host ' — verificando DCs...' -ForegroundColor DarkGray -NoNewline

        try {
            $resultados = Invoke-Command -ComputerName $DCs -ScriptBlock $ScriptBloco -ErrorAction Stop
            $failureCount = 0

            $novos = 0
            if ($resultados) {
                foreach ($evento in ($resultados | Sort-Object TimeCreated)) {
                    $uid = "$($evento.OrigemDC)-$($evento.RecordId)"
                    if (-not $processedEvents.Add($uid)) { continue }

                    $userName      = $evento.TargetUserName
                    $callerComp    = $evento.CallerComputer
                    $dcNome        = $evento.OrigemDC

                    $deveExibir = -not $MonitorEspecifico -or ($userName -ieq $UsuarioAlvo)
                    if (-not $deveExibir) { continue }

                    # Atualiza estatísticas
                    $script:Stats.TotalBloqueios++
                    $script:Stats.UltimaHora.Enqueue((Get-Date))
                    $script:Stats.BloqueiosPorDC[$dcNome]++
                    if (-not $script:Stats.BloqueiosPorUser.ContainsKey($userName)) {
                        $script:Stats.BloqueiosPorUser[$userName] = 0
                    }
                    $script:Stats.BloqueiosPorUser[$userName]++
                    $novos++

                    Format-LockoutEvent -Evento $evento -TargetUserName $userName `
                                        -CallerComputer $callerComp -DCNome $dcNome
                }
            }

            if ($novos -gt 0) {
                Write-Host " +$novos novo(s)" -ForegroundColor Red
            } else {
                Write-Host ' OK' -ForegroundColor DarkGreen
            }

            # Painel de resumo a cada 30 ciclos
            if ($ciclo % 30 -eq 0) { Show-StatsPanel }
        }
        catch {
            $failureCount++
            Write-Host ' FALHA' -ForegroundColor Red

            $msg  = $_.Exception.Message
            $type = $_.Exception.GetType().Name
            $line = $_.InvocationInfo.ScriptLineNumber

            Write-Host ''
            Write-Separator -Char '─' -Color DarkRed
            Write-Host '  ERRO DE PSREMOTING' -ForegroundColor Red
            Write-Separator -Char '─' -Color DarkRed
            Write-KeyValue -Key 'Tipo'     -Value $type           -ValueColor Yellow
            Write-KeyValue -Key 'Linha PS' -Value $line           -ValueColor Yellow
            Write-KeyValue -Key 'Mensagem' -Value $msg            -ValueColor Red

            $diagnostico = switch -Regex ($msg) {
                'timeout|WinRM|timed out|TimeoutException' {
                    @{ D='Timeout de comunicação com DC'; S='Verificar ping/telnet 5985; aumentar -OperationTimeoutSec; checar WinRM.' }
                }
                'Access Denied|Acesso Negado|Unauthorized|permission' {
                    @{ D='Credenciais insuficientes'; S='Executar como Admin de Domínio; verificar Trusted Hosts (WSMan:\localhost\Client\TrustedHosts).' }
                }
                'não está conectado|not connected|WinRM não está' {
                    @{ D='WinRM desabilitado'; S='Enable-PSRemoting -Force no DC; verificar firewall; Restart-Service WinRM.' }
                }
                'firewall|port|porta' {
                    @{ D='Bloqueio de firewall'; S='Liberar portas 5985/5986; Test-NetConnection -ComputerName DC -Port 5985.' }
                }
                'host|resolvido|DNS|não encontrado' {
                    @{ D='Falha de resolução DNS'; S='nslookup no DC; checar Get-DnsClientServerAddress; usar FQDN ou IP.' }
                }
                default {
                    @{ D='Erro não categorizado'; S='Verificar WinRM e conectividade de rede.' }
                }
            }

            Write-Host ''
            Write-KeyValue -Key 'Diagnóstico' -Value $diagnostico.D -ValueColor Cyan
            Write-KeyValue -Key 'Sugestão'    -Value $diagnostico.S -ValueColor DarkYellow
            Write-Separator -Char '─' -Color DarkRed
            Write-Host ''

            if ($failureCount -ge 3) {
                Write-Host ''
                Write-Host '  3 falhas consecutivas — encerrando monitoramento.' -ForegroundColor Red
                break
            }
            Write-StatusBar "Tentativa $failureCount/3 — aguardando próximo ciclo..." 'Yellow'
        }

        Start-Sleep -Seconds 10
    }

    # Exibe resumo final ao sair
    Write-Host ''
    Write-Separator -Char '═' -Color Cyan
    Write-Host '  SESSÃO ENCERRADA' -ForegroundColor Cyan
    Write-Separator -Char '═' -Color Cyan
    Show-StatsPanel
}

#endregion

#region ── PRÉ-REQUISITOS / PSREMOTING ──────────────────────

function Test-PSRemotingAvailability {
    param([string[]]$ComputerNames)

    $disponivel = $true
    $resultados = @()

    foreach ($dc in $ComputerNames) {
        Write-Host "  Testando PSRemoting em $dc" -ForegroundColor DarkGray -NoNewline
        try {
            Test-WSMan -ComputerName $dc -ErrorAction Stop | Out-Null
            Write-Host ' — OK' -ForegroundColor Green
            $resultados += @{ DC=$dc; Status='OK'; Erro=$null }
        }
        catch {
            $msg  = $_.Exception.Message
            $code = $_.Exception.HResult
            $type = $_.Exception.GetType().Name
            Write-Host " — FALHA ($type)" -ForegroundColor Red
            Write-Host "      $msg" -ForegroundColor DarkRed

            $causa = switch -Regex ($msg) {
                'timeout|timed out|WinRM'               { 'Timeout ou WinRM desabilitado' }
                'Access Denied|Unauthorized'            { 'Credenciais insuficientes' }
                'not found|não resolvido|resolver'      { 'Nome inválido ou DNS' }
                'firewall|porta|port'                   { 'Firewall bloqueando 5985/5986' }
                default                                 { 'Causa indeterminada' }
            }
            Write-Host "      Causa provável: $causa" -ForegroundColor DarkYellow

            $resultados += @{ DC=$dc; Status='FALHA'; Erro=$msg; ErrorType=$type }
            $disponivel  = $false
        }
    }
    return @{ Disponivel=$disponivel; Detalhes=$resultados }
}

function Show-PSRemotingDiagnostics {
    param([string[]]$ComputerNames)
    Clear-Host
    Write-Header -Title 'DIAGNÓSTICO DE PSREMOTING' -Subtitle 'Verificação de pré-requisitos de conectividade'

    Write-Host '  [1] WinRM local' -ForegroundColor Yellow
    try {
        $svc = Get-Service -Name WinRM
        Write-Host "      Serviço WinRM: $($svc.Status)" -ForegroundColor $(if ($svc.Status -eq 'Running') {'Green'} else {'Red'})
    } catch {
        Write-Host '      WinRM inacessível.' -ForegroundColor Red
    }

    Write-Host ''
    Write-Host '  [2] WSMan nos DCs' -ForegroundColor Yellow
    foreach ($dc in $ComputerNames) {
        Write-Host "      $dc  " -ForegroundColor DarkGray -NoNewline
        try {
            Test-WSMan -ComputerName $dc -EA SilentlyContinue | Out-Null
            Write-Host 'ATIVO' -ForegroundColor Green
        } catch {
            Write-Host 'INATIVO' -ForegroundColor Red
        }
    }

    Write-Host ''
    Write-Host '  [3] Trusted Hosts' -ForegroundColor Yellow
    try {
        $th = (Get-Item WSMan:\localhost\Client\TrustedHosts -EA SilentlyContinue).Value
        if ($th) { Write-Host "      $th" -ForegroundColor Green }
        else      { Write-Host '      (vazio — aceita todos)' -ForegroundColor Yellow }
    } catch {
        Write-Host '      Erro ao ler Trusted Hosts.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '  [4] Portas WSMan (5985 / 5986)' -ForegroundColor Yellow
    foreach ($dc in $ComputerNames) {
        $p1 = Test-NetConnection -ComputerName $dc -Port 5985 -InformationLevel Quiet -EA SilentlyContinue
        $p2 = Test-NetConnection -ComputerName $dc -Port 5986 -InformationLevel Quiet -EA SilentlyContinue
        $ok = $p1 -or $p2
        Write-Host "      $dc  " -ForegroundColor DarkGray -NoNewline
        Write-Host $(if ($ok) {'ACESSÍVEL'} else {'INACESSÍVEL'}) -ForegroundColor $(if ($ok) {'Green'} else {'Red'})
    }

    Write-Host ''
    Write-Host '  [5] Sistema local' -ForegroundColor Yellow
    Write-Host "      SO: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Gray
    Write-Host "      PS: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)" -ForegroundColor Gray
    Write-Host ''
}

function Show-PSRemotingInstructions {
    Clear-Host
    Write-Header -Title 'PSREMOTING NÃO HABILITADO' -Subtitle 'Execute os passos abaixo para habilitar'

    Write-Host '  Em cada Domain Controller (como Administrador):' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '      Enable-PSRemoting -Force -SkipNetworkProfileCheck' -ForegroundColor Green
    Write-Host ''
    Write-Separator
    Write-Host '  Ou remotamente, de um DC para todos:' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "      `$DCs = @('SSOOAD01','SSOOAD02')" -ForegroundColor Green
    Write-Host "      `$DCs | ForEach-Object {" -ForegroundColor Green
    Write-Host '          Invoke-Command -ComputerName $_ -ScriptBlock {' -ForegroundColor Green
    Write-Host '              Enable-PSRemoting -Force -SkipNetworkProfileCheck' -ForegroundColor Green
    Write-Host '          }' -ForegroundColor Green
    Write-Host '      }' -ForegroundColor Green
    Write-Host ''
    Write-Separator
    Write-Host '  Opções:' -ForegroundColor White
    Write-Host '  [1]  Executar diagnóstico completo de PSRemoting' -ForegroundColor Cyan
    Write-Host '  [2]  Habilitar PSRemoting automaticamente (requer admin)' -ForegroundColor Cyan
    Write-Host '  [3]  Sair' -ForegroundColor DarkGray
    Write-Host ''

    return (Read-Host '  Escolha (1, 2 ou 3)')
}

function Enable-PSRemotingOnDCs {
    param([string[]]$ComputerNames)
    Write-Host ''
    Write-StatusBar 'Habilitando PSRemoting nos DCs...' 'Green'
    foreach ($dc in $ComputerNames) {
        Write-Host "  $dc  " -ForegroundColor DarkGray -NoNewline
        try {
            Invoke-Command -ComputerName $dc -ScriptBlock { Enable-PSRemoting -Force -SkipNetworkProfileCheck } -EA Stop | Out-Null
            Write-Host 'OK' -ForegroundColor Green
        } catch {
            Write-Host "FALHA — $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host ''
    Write-StatusBar 'Concluído. Reiniciando em 2 segundos...' 'Green'
    Start-Sleep -Seconds 2
}

#endregion

#region ── PONTO DE ENTRADA ──────────────────────────────────

try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                 [Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host ''
        Write-Host '  Este script requer privilégios de ADMINISTRADOR.' -ForegroundColor Yellow
        Write-Host '  Reinicie o PowerShell como Administrador.' -ForegroundColor DarkGray
        Start-Sleep -Seconds 2
        exit
    }

    Write-Host ''
    Write-StatusBar 'Verificando disponibilidade de PSRemoting...' 'Cyan'
    $testRemoting = Test-PSRemotingAvailability -ComputerNames $DCs

    if (-not $testRemoting.Disponivel) {
        Write-Host ''
        Write-StatusBar 'Alguns DCs não responderam ao PSRemoting.' 'Yellow'

        do {
            $opcao = Show-PSRemotingInstructions
            switch ($opcao) {
                '1' { Show-PSRemotingDiagnostics -ComputerNames $DCs; pause }
                '2' { Enable-PSRemotingOnDCs -ComputerNames $DCs }
                '3' { exit }
                default { Write-Host '  Opção inválida.' -ForegroundColor Red }
            }
        } while ($opcao -notin @('2','3'))
    }

    $choice = Get-MonitoringChoice
    Start-ADLockoutMonitor -MonitoringChoice $choice
}
catch {
    Write-Host ''
    Write-Host '  ERRO CRÍTICO: ' -ForegroundColor Red -NoNewline
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host '  Stack: ' -ForegroundColor DarkRed -NoNewline
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    Write-Host ''
    Read-Host '  Pressione Enter para sair'
}

#endregion
