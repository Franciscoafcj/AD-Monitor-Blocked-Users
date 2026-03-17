# 🔐 AD Lockout Monitor v2.0

> Monitor de bloqueios de conta do Active Directory em tempo real, com análise de origem, diagnóstico automático e estatísticas de sessão.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)
![Active Directory](https://img.shields.io/badge/Active%20Directory-required-0078D4?logo=microsoft&logoColor=white)
![PSRemoting](https://img.shields.io/badge/PSRemoting-WinRM-green)
![Event ID](https://img.shields.io/badge/Event%20ID-4740-red)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Funcionalidades](#-funcionalidades)
- [Pré-requisitos](#-pré-requisitos)
- [Instalação e Uso](#-instalação-e-uso)
- [Arquitetura](#-arquitetura)
- [Referência de Funções](#-referência-de-funções)
- [Análise de Origem](#-análise-de-origem)
- [Tratamento de Erros](#-tratamento-de-erros)
- [Estrutura de Dados](#-estrutura-de-dados)
- [Segurança](#-segurança)
- [FAQ](#-faq)

---

## 🔍 Visão Geral

O **AD Lockout Monitor** é um script PowerShell que monitora eventos de bloqueio de conta (Event ID 4740) em todos os Domain Controllers do domínio simultaneamente, via PSRemoting. A cada ciclo de 10 segundos, novos bloqueios são detectados, classificados por origem e exibidos no console com diagnóstico contextualizado.

```
╔══════════════════════════════════════════════════════════════════════╗
║               AD LOCKOUT MONITOR  v2.0                               ║
║      Active Directory — Monitor de Bloqueios em Tempo Real           ║
╚══════════════════════════════════════════════════════════════════════╝

  Início                dd/MM/yyyy HH:mm:ss
  Domain Controllers    DC01  |  DC02  |  DC03
  Modo de busca         Remoto via PSRemoting
  Intervalo             10 segundos por ciclo

  Pressione Ctrl+C para encerrar.
```

---

## ✨ Funcionalidades

| Feature | Detalhe |
|---|---|
| ⚡ **Tempo real** | Ciclos de 10 s com polling paralelo em todos os DCs |
| 🎯 **Filtro por usuário** | Monitora todos ou filtra por uma conta específica |
| 🔍 **Análise de origem** | Classifica o dispositivo de origem em 5 categorias |
| 🚦 **Severidade** | Três níveis: Alta (VPN/FW), Média (Exchange/DC), Baixa (Workstation) |
| ♻️ **Deduplicação** | HashSet por `DC + RecordId` — cada evento processado exatamente uma vez |
| 📊 **Estatísticas** | Contadores por sessão, por DC, por usuário e janela deslizante de 60 min |
| 🛡️ **Auto-diagnóstico** | Detecta e categoriza falhas de WinRM com sugestão de correção |
| 🔧 **Setup automático** | Habilita PSRemoting nos DCs automaticamente se necessário |

---

## 📦 Pré-requisitos

- **PowerShell 5.1** ou superior
- **Módulo ActiveDirectory** (RSAT — instalado automaticamente se disponível)
- **Privilégio de Administrador** na máquina de execução
- **Leitura do log Security** nos Domain Controllers (grupo *Event Log Readers* ou Admin de Domínio)
- **WinRM habilitado** em todos os DCs (portas **5985** e/ou **5986** acessíveis)
- **DNS** — resolução de nomes dos DCs a partir da máquina de execução

> [!WARNING]
> O script verifica automaticamente se está sendo executado como Administrador e encerra caso contrário.

---

## 🚀 Instalação e Uso

### 1. Clone ou baixe o script

```powershell
git clone https://github.com/seu-usuario/ad-lockout-monitor.git
cd ad-lockout-monitor
```

### 2. Execute como Administrador

```powershell
.\ADLockoutMonitor.ps1
```

### 3. Selecione o modo de monitoramento

```
  [1]  Monitorar TODOS os usuários
  [2]  Monitorar um USUÁRIO ESPECÍFICO
```

#### Monitorar todos os usuários
Escolha `[1]` — todos os bloqueios de qualquer conta serão exibidos em tempo real.

#### Monitorar usuário específico
Escolha `[2]` e informe o `sAMAccountName`:

```
  Usuário (ex: francisco.silva): joao.silva
```

> [!NOTE]
> No modo específico, as estatísticas globais continuam sendo coletadas para todos os usuários — apenas a exibição é filtrada.

### 4. Encerrar

Pressione `Ctrl+C` a qualquer momento. O painel de estatísticas final é exibido automaticamente.

---

## 🏗️ Arquitetura

O script está organizado em **8 regiões** delimitadas por `#region`/`#endregion`:

```
ADLockoutMonitor.ps1
│
├── #region INICIALIZAÇÃO
│   ├── Import-Module ActiveDirectory
│   ├── $DCs  ← Get-ADDomainController -Filter *
│   ├── $cacheDns  ← cache de resolução DNS
│   └── $script:Stats  ← contadores globais de sessão
│
├── #region HELPERS DE INTERFACE
│   ├── Write-Separator   ← linhas horizontais
│   ├── Write-Header      ← caixas com borda dupla (╔═╗)
│   ├── Write-StatusBar   ← linhas com timestamp
│   ├── Write-KeyValue    ← pares chave–valor em colunas
│   └── Write-Badge       ← rótulos com fundo colorido
│
├── #region ANÁLISE DE ORIGEM
│   └── Get-SourceAnalysis  ← classifica CallerComputer + resolve DNS
│
├── #region FORMATAÇÃO DE EVENTOS
│   └── Format-LockoutEvent  ← renderiza alerta completo no console
│
├── #region PAINEL DE ESTATÍSTICAS
│   └── Show-StatsPanel  ← resumo acumulado da sessão
│
├── #region TELA DE SELEÇÃO
│   └── Get-MonitoringChoice  ← menu interativo de modo
│
├── #region MONITORAMENTO PRINCIPAL
│   └── Start-ADLockoutMonitor  ← loop principal de polling
│
└── #region PRÉ-REQUISITOS / PSREMOTING
    ├── Test-PSRemotingAvailability
    ├── Show-PSRemotingDiagnostics
    ├── Show-PSRemotingInstructions
    └── Enable-PSRemotingOnDCs
```

### Fluxo de execução

```
Início
  │
  ├─ [Verificação] Administrador? ──► Não → encerra
  │
  ├─ [Teste] Test-PSRemotingAvailability
  │     └─ Falha? → menu: [1] Diagnóstico  [2] Habilitar  [3] Sair
  │
  ├─ [Menu] Get-MonitoringChoice → Todos | Específico
  │
  └─ [Loop] Start-ADLockoutMonitor ──────────────────────────────┐
        │                                                         │
        ├─ Invoke-Command (paralelo nos DCs) → eventos 4740       │
        ├─ Deduplica por HashSet                                  │
        ├─ Filtra por usuário (se modo específico)                │
        ├─ Atualiza $script:Stats                                 │
        ├─ Format-LockoutEvent → exibe alerta                     │
        ├─ ciclo % 30 == 0 → Show-StatsPanel                      │
        ├─ erro → diagnóstico → failCount++                       │
        │     └─ failCount >= 3 → break ──────────────────────────┘
        └─ Start-Sleep 10s → repete
              │
              ▼
        Show-StatsPanel (resumo final)
```

---

## 📖 Referência de Funções

### `Get-SourceAnalysis`

Classifica o dispositivo de origem (`CallerComputer`) do evento 4740 e resolve seu IP via DNS com cache em memória.

**Parâmetro:**

| Nome | Tipo | Descrição |
|---|---|---|
| `-CallerComputer` | `String` | Nome do dispositivo (Properties[3] do evento 4740) |

**Retorno:** `Hashtable` com as chaves `IP`, `Icone`, `Tipo`, `Suspeita`, `Sev`

---

### `Format-LockoutEvent`

Renderiza o alerta completo no console com badge de severidade, campos do evento e diagnóstico.

**Parâmetros:**

| Nome | Tipo | Descrição |
|---|---|---|
| `-Evento` | `PSCustomObject` | Objeto retornado pelo `Invoke-Command` remoto |
| `-TargetUserName` | `String` | Usuário bloqueado — `Properties[0]` |
| `-CallerComputer` | `String` | Dispositivo de origem — `Properties[3]` |
| `-DCNome` | `String` | Nome do DC que registrou o evento |

---

### `Show-StatsPanel`

Exibe painel com estatísticas acumuladas. Chamado a cada **30 ciclos** e no encerramento.

Campos exibidos: tempo de execução, ciclos, total de bloqueios, bloqueios na última hora, DCs monitorados, contagem por DC, top 3 usuários.

---

### `Start-ADLockoutMonitor`

Loop principal de monitoramento.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `-MonitoringChoice` | `Hashtable` | Retornado por `Get-MonitoringChoice` (`Tipo` + `Usuario`) |

**Variáveis de configuração internas:**

| Variável | Padrão | Efeito |
|---|---|---|
| `$lastChecked` | `Now - 7 dias` | Janela retroativa inicial de coleta |
| `Start-Sleep` | `10 segundos` | Intervalo entre ciclos |
| `ciclo % 30` | `30` | Frequência do painel de resumo |
| `$failureCount` | `3` | Máximo de falhas consecutivas antes de encerrar |

---

### `Test-PSRemotingAvailability`

Executa `Test-WSMan` em cada DC. Retorna `@{ Disponivel=$bool; Detalhes=@(...) }`.

---

### `Show-PSRemotingDiagnostics`

Diagnóstico de conectividade em 5 etapas:

1. Status do serviço WinRM local
2. Teste WSMan em cada DC
3. Conteúdo de `WSMan:\localhost\Client\TrustedHosts`
4. Teste de portas 5985/5986 via `Test-NetConnection`
5. Versão do SO e do PowerShell

---

### `Enable-PSRemotingOnDCs`

Executa `Enable-PSRemoting -Force -SkipNetworkProfileCheck` via `Invoke-Command` em cada DC.

---

## 🔎 Análise de Origem

O `Get-SourceAnalysis` classifica o `CallerComputer` por regex e atribui severidade:

| Padrão (Regex) | Ícone | Tipo | Severidade | Diagnóstico |
|---|---|---|---|---|
| *(vazio / `-`)* | `[?]` | Origem Oculta | 🟡 Média | Celular via ActiveSync, RADIUS/NPS ou mapeamento externo |
| `EXCH\|MAIL\|OWA\|WEB` | `[M]` | Servidor E-mail/Web | 🟡 Média | Senha desatualizada em dispositivo móvel (ActiveSync) |
| `DC0\|AD0\|SRV-AD` | `[D]` | Domain Controller | 🟡 Média | Autenticação direta; verificar Wi-Fi (NPS), VPN ou scripts |
| `VPN\|FW\|FIREWALL` | `[!]` | Gateway / VPN | 🔴 Alta | Conexão externa; possível ataque de força bruta |
| `FS\|FILE\|ARQUIVO` | `[F]` | File Server | 🟢 Baixa | Mapeamento de rede com credenciais antigas |
| *(default)* | `[W]` | Estação de Trabalho | 🟢 Baixa | Verificar Gerenciador de Credenciais ou Tarefas Agendadas |

> [!TIP]
> O cache DNS (`$cacheDns`) armazena `CallerComputer → IP` para evitar chamadas repetidas ao DNS durante a sessão.

---

## ⚠️ Tratamento de Erros

O bloco `catch` do loop principal categoriza automaticamente as exceções de PSRemoting:

| Padrão na mensagem | Diagnóstico | Sugestão |
|---|---|---|
| `timeout \| WinRM \| timed out` | Timeout de comunicação | Verificar ping/telnet 5985; aumentar `-OperationTimeoutSec`; checar WinRM |
| `Access Denied \| Unauthorized` | Credenciais insuficientes | Executar como Admin de Domínio; verificar `TrustedHosts` |
| `WinRM não está \| not connected` | WinRM desabilitado | `Enable-PSRemoting -Force` no DC; verificar firewall; `Restart-Service WinRM` |
| `firewall \| port` | Bloqueio de firewall | Liberar portas 5985/5986; `Test-NetConnection -ComputerName DC -Port 5985` |
| `host \| DNS \| não encontrado` | Falha de DNS | `nslookup` no DC; usar FQDN ou IP; checar `Get-DnsClientServerAddress` |
| *(default)* | Erro não categorizado | Verificar WinRM e conectividade de rede |

> [!CAUTION]
> Após **3 falhas consecutivas**, o monitoramento é encerrado automaticamente e o painel de estatísticas final é exibido.

---

## 🗄️ Estrutura de Dados

### `$script:Stats`

Hashtable global de sessão, persistido durante toda a execução:

| Chave | Tipo | Descrição |
|---|---|---|
| `TotalBloqueios` | `Int` | Contador acumulado de eventos únicos |
| `UltimaHora` | `Queue<DateTime>` | Fila para janela deslizante de 60 min |
| `BloqueiosPorDC` | `Hashtable` | Contagem de bloqueios indexada por nome de DC |
| `BloqueiosPorUser` | `Hashtable` | Contagem de bloqueios indexada por username |
| `CicloAtual` | `Int` | Número do ciclo em execução |
| `Inicio` | `DateTime` | Timestamp de início (base do uptime) |

### `$cacheDns`

`Hashtable` de escopo de script. Armazena `CallerComputer → IP`. Valor é `$null` se a resolução falhar.

### `$processedEvents`

`HashSet<String>` com IDs de eventos já processados no formato `"NomeDC-RecordId"`. Garante que cada evento seja exibido exatamente uma vez entre ciclos.

---

## 🔒 Segurança

> [!WARNING]
> Execute apenas em ambientes controlados, com credenciais dedicadas de monitoramento. O acesso ao log de Segurança dos DCs é altamente privilegiado.

- **Permissões mínimas:** membro do grupo *Event Log Readers* + permissão de PSRemoting nos DCs
- **Sem escrita:** o script apenas lê eventos e não modifica nenhum objeto do AD
- **Cache DNS:** mantido apenas em memória durante a sessão, sem persistência em disco
- **HashSet de eventos:** cresce ao longo da sessão — em ambientes com alto volume, considere reiniciar o script periodicamente
- **PSRemoting:** use credenciais com menor privilégio possível; considere *Just Enough Administration (JEA)*

---

## ❓ FAQ

**O script trava na verificação de PSRemoting — o que fazer?**

Execute o diagnóstico completo (`[1]` no menu de PSRemoting) ou verifique manualmente:

```powershell
# Testar conectividade WinRM
Test-NetConnection -ComputerName NOME-DO-DC -Port 5985

# Verificar serviço WinRM local
Get-Service WinRM

# Habilitar PSRemoting em um DC remotamente
Invoke-Command -ComputerName NOME-DO-DC -ScriptBlock {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
}
```

---

**Posso executar sem ser Admin de Domínio?**

Sim, com permissões reduzidas: adicione a conta ao grupo *Event Log Readers* nos DCs e configure permissões de PSRemoting para essa conta. O script ainda exigirá privilégio de Administrador local para iniciar.

---

**O script exibe bloqueios retroativos ao iniciar — é normal?**

Sim. A variável `$lastChecked` é inicializada com `Now - 7 dias` para capturar eventos recentes na primeira execução. Após o primeiro ciclo, apenas novos eventos serão processados (deduplicação via HashSet).

---

**Como ajustar o intervalo de polling?**

Localize a linha `Start-Sleep -Seconds 10` dentro da função `Start-ADLockoutMonitor` e altere o valor conforme necessário. Valores abaixo de 5 segundos podem gerar carga excessiva nos DCs.

---

**Como ajustar a frequência do painel de resumo?**

Localize `if ($ciclo % 30 -eq 0)` e altere o divisor. Ex.: `% 10` exibe o painel a cada 10 ciclos (~100 segundos).

---

## 📄 Licença

MIT — consulte o arquivo [LICENSE](LICENSE) para detalhes.
