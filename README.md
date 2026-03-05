# 🔐 AD Monitor Blocked Users

**Ferramenta avançada de monitoramento em tempo real de bloqueios de conta no Active Directory**

## 📋 Descrição

Este script PowerShell monitora continuamente os **bloqueios de conta de usuários** no Active Directory (AD), fornecendo informações detalhadas sobre:

- ✅ Qual usuário foi bloqueado
- 🕒 Quando ocorreu o bloqueio
- 💻 De qual dispositivo/máquina o bloqueio originou
- 🌐 IP da máquina de origem (resolvido automaticamente)
- 🔍 Diagnóstico inteligente sobre a origem do bloqueio

## 🚀 Características Principais

### Monitoramento Flexível
- **Modo Todos**: Monitora bloqueios de todos os usuários do AD
- **Modo Específico**: Foca em monitorar um usuário específico

### Diagnóstico Inteligente
O script analisa automaticamente o nome da máquina de origem e identifica:
- 📱 Servidores de e-mail (indicativos de celulares com senha desatualizada)
- 🔄 Domain Controllers
- 🌍 Gateways/VPN
- 📁 File Servers
- 💻 Estações de trabalho padrão

### Execução Remota
- 🌐 Conecta-se a **todos os Domain Controllers em paralelo** via PSRemoting
- ⚡ Busca distribuída de alta velocidade
- 🔄 Cache de DNS para otimização

### Cache Inteligente
- Armazena em cache resoluções de DNS para evitar consultas repetidas
- Rastreia eventos já processados para evitar duplicatas

## 📋 Pré-requisitos

### Sistema
- **Windows Server** com PowerShell 5.0 ou superior
- Acesso ao **Active Directory** (módulo ActiveDirectory instalado)
- Privilégios de **Administrador Local**
- Privilégios de **Administrador de Domínio** (recomendado)

### Módulos PowerShell Obrigatórios
```powershell
# Verificar módulos instalados
Get-Module -ListAvailable | grep ActiveDirectory
Get-Module -ListAvailable | grep GroupPolicy
```

### Configuração de PSRemoting
O script requer **PSRemoting habilitado nos Domain Controllers**.

#### Habilitar em cada DC (como Administrador):
```powershell
Enable-PSRemoting -Force -SkipNetworkProfileCheck
```

#### Ou remotamente (de um DC para todos os outros):
```powershell
$DCs = @('SSOOAD01', 'SSOOAD02')  # Altere conforme seus DCs
$DCs | ForEach-Object {
    Invoke-Command -ComputerName $_ -ScriptBlock {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck
    }
}
```

### Conectividade de Rede
- Portas **5985 (HTTP)** e **5986 (HTTPS)** abertas para WSMan
- Firewall permitindo PSRemoting entre máquinas

## 🎯 Como Usar

### 1. Executar o Script
```powershell
# Como Administrador
.\AD-Monitor-Blocked-Users.ps1
```

### 2. Escolher Modo de Monitoramento

O script exibirá um menu:
```
╔══════════════════════════════════════════════════╗
║        MONITOR DE BLOQUEIOS - ACTIVE DIRECTORY   ║
╠══════════════════════════════════════════════════╣
║ Selecione o tipo de monitoramento:               ║
║                                                  ║
║ 1) Monitorar TODOS os usuários                   ║
║ 2) Monitorar um USUÁRIO ESPECÍFICO               ║
║                                                  ║
║ Pressione 1 ou 2...                              ║
╚══════════════════════════════════════════════════╝
```

**Opção 1**: Monitora todos os bloqueios em tempo real
**Opção 2**: Solicita o nome do usuário e monitora apenas esse

### 3. Interpretar Resultados

Quando um bloqueio é detectado:
```
==================================================
 🚨 BLOQUEIO DETECTADO 
==================================================
👤 Usuário:        usuario.silva
🕒 Data/Hora:      2026-03-05 14:32:15
💻 Disp. de Origem: PC-MARIA-001
🌐 IP Resolvido:    192.168.1.150
🔎 Diagnóstico:    Estação de Trabalho / Dispositivo Padrão
--------------------------------------------------
```

## 📊 Estrutura do Script

### Funções Principais

#### `Get-MonitoringChoice`
Exibe menu interativo para seleção do tipo de monitoramento.

**Retorna:**
```powershell
@{
    Tipo = "Todos" | "Especifico"
    Usuario = $null | "nome.usuario"
}
```

#### `Get-SourceAnalysis`
Analisa a máquina de origem do bloqueio.

**Parâmetros:**
- `$CallerComputer` - Nome da máquina de origem

**Retorna:**
```powershell
@{
    IP = "IP resolvido" | "Não resolvido"
    Suspeita = "Diagnóstico da origem"
}
```

**Lógica de Diagnóstico:**
| Pattern | Diagnóstico |
|---------|-------------|
| EXCH, MAIL, OWA, WEB | Servidor de E-mail/Web (celular) |
| DC0, AD0, SRV-AD | Domain Controller |
| VPN, FW, FIREWALL | Gateway/VPN |
| FS, FILE, ARQUIVO | File Server |
| Outros | Estação de Trabalho Padrão |

#### `Format-LockoutEvent`
Formata e exibe graficamente um evento de bloqueio.

**Parâmetros:**
- `$evento` - Objeto do evento de bloqueio
- `$TargetUserName` - Nome do usuário bloqueado
- `$CallerComputer` - Máquina de origem

#### `Start-ADLockoutMonitor`
Loop principal de monitoramento em tempo real.

**Funcionalidade:**
- Executa PSRemoting em todos os DCs a cada 10 segundos
- Busca eventos ID 4740 (Account Lockout)
- Processa eventos em paralelo
- Mantém cache de eventos processados para evitar duplicatas

#### `Test-PSRemotingAvailability`
Testa conectividade PSRemoting em todos os DCs.

**Retorna:**
```powershell
@{
    Disponivel = $true | $false
    Detalhes = @(
        @{ DC = "SSOOAD01"; Status = "OK" | "FALHA"; Erro = $null }
    )
}
```

#### `Show-PSRemotingDiagnostics`
Executa diagnóstico completo de PSRemoting com 5 verificações:
1. Status do serviço WinRM local
2. Conectividade WSMan nos DCs
3. Configuração de Trusted Hosts
4. Acessibilidade das portas 5985/5986
5. Informações do sistema local

#### `Enable-PSRemotingOnDCs`
Habilita PSRemoting automaticamente em todos os DCs (requer admin).

## 🔧 Solução de Problemas

### Erro: "PSRemoting não está habilitado"
```
⚠️ ERRO DE PSRemoting - Detalhes:
   • Tipo de Erro: WinRMOperationFailure
   • Mensagem: WinRM não está em execução
```

**Solução:**
```powershell
# Habilitar PSRemoting localmente
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Ou usar o script - escolha opção 2 no menu de diagnóstico
```

### Erro: "Timeout na comunicação com DCs"
```
💡 Diagnóstico: Timeout na comunicação com DCs
```

**Soluções:**
1. Verificar conectividade: `ping DC-NAME`
2. Testar porta WSMan: `Test-NetConnection -ComputerName DC-NAME -Port 5985`
3. Aumentar timeout nos DCs via GPO (WinRM config)

### Erro: "Acesso Negado / Unauthorized"
```
💡 Diagnóstico: Erro de autenticação ou permissão
```

**Soluções:**
1. Verificar privilégios de Admin: `whoami /groups`
2. Adicionar DC aos Trusted Hosts: 
   ```powershell
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
   ```
3. Executar como Administrador do Domínio

### Erro: "Resolução DNS falha"
```
💡 Diagnóstico: Erro de resolução DNS ou nome inválido
```

**Soluções:**
1. Testar DNS: `nslookup DC-NAME`
2. Verificar configuração DNS: `Get-DnsClientServerAddress`
3. Usar FQDN ou IP em vez de NetBIOS

### O script não encontra eventos

**Possíveis causas:**
- Nenhum bloqueio ocorreu no período de monitoramento
- Logs de auditoria não habilitados (Event ID 4740)
- Usuário não tem permissão para ler Security Log

**Verificar auditoria:**
```powershell
# Em um DC, verificar Log de Segurança
Get-WinEvent -FilterHashtable @{ 
    LogName = 'Security'
    ID = 4740
} -MaxEvents 10 | Format-Table TimeCreated, @{N='User';E={$_.Properties[0].Value}}
```

## 📝 Exemplos de Uso

### Exemplo 1: Monitorar Todos os Bloqueios
```powershell
# Executar script
.\AD-Monitor-Blocked-Users.ps1

# Escolher opção 1
# Script exibirá todos os bloqueios em tempo real
```

### Exemplo 2: Monitorar Usuário Específico
```powershell
# Executar script
.\AD-Monitor-Blocked-Users.ps1

# Escolher opção 2
# Digitar: francisco.silva
# Script filtrará apenas bloqueios deste usuário
```

### Exemplo 3: Testar Conectividade antes de Monitorar
```powershell
# Obter DCs
$DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name

# Testar cada DC
foreach ($dc in $DCs) {
    Write-Host "Testando $dc..."
    Test-WSMan -ComputerName $dc -ErrorAction SilentlyContinue
}
```

## 🔐 Segurança

### Recomendações
- ✅ Execute sempre como **Administrador do Domínio**
- ✅ Configure **firewall** adequadamente
- ✅ Use **HTTPS para PSRemoting** em produção
- ✅ Implemente **logging** dos monitoramentos (considere redirecionar output)
- ✅ Restrinja acesso ao script (permissões de arquivo)

### Dados Coletados
O script coleta:
- Nome de usuário
- Timestamp do bloqueio
- Nome da máquina de origem
- IP da máquina (resolvido)
- Domain Controller de origem

**Estes dados NÃO são armazenados**, apenas exibidos no console.

## 📈 Performance

### Otimizações Implementadas
- 🔄 **Cache DNS**: Evita resolver mesmo host múltiplas vezes
- ⚡ **Execução Paralela**: Consulta todos os DCs simultaneamente
- 🎯 **Filtragem Inteligente**: Apenas busca eventos dos últimos 5 minutos
- 📦 **HashSet**: Rastreia eventos processados sem duplicatas

### Intervalo de Verificação
- **10 segundos** entre ciclos de busca
- Ajustável modificando `Start-Sleep -Seconds 10` no loop

## 🐛 Limitações Conhecidas

1. **Requer PSRemoting**: Não funciona sem acesso remoto aos DCs
2. **Eventos Locais**: Não monitora ativa contra ataques em DCs específicos
3. **Cache em Memória**: Limpo ao reiniciar o script
4. **Timezone**: Usa timezone do servidor onde o script executa

## 📞 Suporte e Diagnóstico

Para diagnóstico completo, execute:
```powershell
# Opção automática no script
# Escolha a opção de diagnóstico no menu de PSRemoting

# Ou manualmente
$DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name
Show-PSRemotingDiagnostics -ComputerNames $DCs
```

## 📄 Licença e Uso

- Script de **código aberto**
- Use livremente em seu ambiente
- Customize conforme necessário
- Teste em ambiente de teste primeiro

---

**Versão:** 2.0  
**Última Atualização:** Março 2026  
**Testado em:** Windows Server 2019, 2022 com PowerShell 5.1+
