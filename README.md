<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AD Lockout Monitor v2.0 — Documentação</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;700&family=Syne:wght@400;600;700;800&display=swap" rel="stylesheet">
<style>
  :root {
    --bg:        #0b0e14;
    --bg2:       #111520;
    --bg3:       #161b27;
    --border:    #1e2638;
    --border2:   #2a3349;
    --accent:    #00d4ff;
    --accent2:   #0091b5;
    --green:     #00ff9d;
    --green2:    #00b86e;
    --red:       #ff4757;
    --yellow:    #ffd32a;
    --purple:    #a855f7;
    --text:      #c8d3e8;
    --text2:     #7a8ba8;
    --text3:     #4a5870;
    --white:     #edf2ff;
    --mono:      'JetBrains Mono', monospace;
    --sans:      'Syne', sans-serif;
  }

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  html { scroll-behavior: smooth; }

  body {
    background: var(--bg);
    color: var(--text);
    font-family: var(--mono);
    font-size: 14px;
    line-height: 1.7;
    min-height: 100vh;
  }

  /* ── SCANLINES ── */
  body::before {
    content: '';
    position: fixed;
    inset: 0;
    background: repeating-linear-gradient(
      to bottom,
      transparent 0px,
      transparent 2px,
      rgba(0,0,0,.07) 2px,
      rgba(0,0,0,.07) 4px
    );
    pointer-events: none;
    z-index: 1000;
  }

  /* ── GRID LAYOUT ── */
  .layout {
    display: grid;
    grid-template-columns: 260px 1fr;
    min-height: 100vh;
  }

  /* ── SIDEBAR ── */
  aside {
    position: sticky;
    top: 0;
    height: 100vh;
    overflow-y: auto;
    background: var(--bg2);
    border-right: 1px solid var(--border);
    padding: 0;
    display: flex;
    flex-direction: column;
  }

  aside::-webkit-scrollbar { width: 4px; }
  aside::-webkit-scrollbar-track { background: var(--bg2); }
  aside::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 2px; }

  .sidebar-brand {
    padding: 28px 20px 20px;
    border-bottom: 1px solid var(--border);
  }

  .sidebar-brand .tag {
    font-family: var(--mono);
    font-size: 10px;
    font-weight: 500;
    color: var(--accent2);
    letter-spacing: .12em;
    text-transform: uppercase;
    margin-bottom: 6px;
  }

  .sidebar-brand h1 {
    font-family: var(--sans);
    font-size: 17px;
    font-weight: 800;
    color: var(--white);
    line-height: 1.2;
    letter-spacing: -.01em;
  }

  .sidebar-brand .version {
    display: inline-block;
    margin-top: 8px;
    padding: 2px 8px;
    background: rgba(0,212,255,.1);
    border: 1px solid rgba(0,212,255,.3);
    border-radius: 3px;
    font-size: 11px;
    color: var(--accent);
    letter-spacing: .05em;
  }

  nav { padding: 16px 0 24px; flex: 1; }

  nav .nav-section {
    padding: 12px 20px 4px;
    font-size: 9px;
    font-weight: 700;
    letter-spacing: .15em;
    text-transform: uppercase;
    color: var(--text3);
  }

  nav a {
    display: block;
    padding: 7px 20px 7px 28px;
    color: var(--text2);
    text-decoration: none;
    font-size: 12.5px;
    font-weight: 400;
    transition: color .15s, background .15s;
    border-left: 2px solid transparent;
    position: relative;
  }

  nav a::before {
    content: '›';
    position: absolute;
    left: 16px;
    color: var(--text3);
    transition: color .15s;
  }

  nav a:hover {
    color: var(--white);
    background: rgba(255,255,255,.03);
    border-left-color: var(--border2);
  }

  nav a:hover::before { color: var(--accent); }

  nav a.active {
    color: var(--accent);
    border-left-color: var(--accent);
    background: rgba(0,212,255,.05);
  }

  nav a.active::before { color: var(--accent); }

  /* ── MAIN CONTENT ── */
  main {
    padding: 48px 56px 96px;
    max-width: 960px;
  }

  /* ── SECTIONS ── */
  section {
    margin-bottom: 72px;
    animation: fadeIn .4s ease both;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(12px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  /* ── HERO ── */
  .hero {
    padding: 48px 0 56px;
    border-bottom: 1px solid var(--border);
    margin-bottom: 64px;
    position: relative;
    overflow: hidden;
  }

  .hero::after {
    content: 'LOCKOUT';
    position: absolute;
    right: -20px;
    top: 50%;
    transform: translateY(-50%);
    font-family: var(--sans);
    font-size: 130px;
    font-weight: 800;
    color: rgba(0,212,255,.03);
    pointer-events: none;
    letter-spacing: -.04em;
    white-space: nowrap;
  }

  .hero-eyebrow {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 18px;
  }

  .dot {
    width: 6px; height: 6px;
    border-radius: 50%;
    background: var(--green);
    box-shadow: 0 0 8px var(--green);
    animation: pulse 2s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; box-shadow: 0 0 8px var(--green); }
    50%       { opacity: .5; box-shadow: 0 0 3px var(--green2); }
  }

  .hero-eyebrow span {
    font-size: 11px;
    letter-spacing: .12em;
    text-transform: uppercase;
    color: var(--green2);
    font-weight: 500;
  }

  .hero h1 {
    font-family: var(--sans);
    font-size: 48px;
    font-weight: 800;
    color: var(--white);
    letter-spacing: -.03em;
    line-height: 1.05;
    margin-bottom: 16px;
  }

  .hero h1 span { color: var(--accent); }

  .hero p {
    font-size: 15px;
    color: var(--text2);
    max-width: 600px;
    line-height: 1.7;
    margin-bottom: 28px;
  }

  .badge-row {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .badge {
    padding: 4px 12px;
    border-radius: 3px;
    font-size: 11px;
    font-weight: 500;
    letter-spacing: .05em;
  }

  .badge-blue  { background: rgba(0,212,255,.12); border: 1px solid rgba(0,212,255,.3); color: var(--accent); }
  .badge-green { background: rgba(0,255,157,.1);  border: 1px solid rgba(0,255,157,.3); color: var(--green); }
  .badge-red   { background: rgba(255,71,87,.1);  border: 1px solid rgba(255,71,87,.3); color: var(--red); }
  .badge-purple{ background: rgba(168,85,247,.1); border: 1px solid rgba(168,85,247,.3); color: var(--purple); }
  .badge-yellow{ background: rgba(255,211,42,.1); border: 1px solid rgba(255,211,42,.3); color: var(--yellow); }

  /* ── HEADINGS ── */
  h2 {
    font-family: var(--sans);
    font-size: 24px;
    font-weight: 700;
    color: var(--white);
    letter-spacing: -.02em;
    margin-bottom: 20px;
    display: flex;
    align-items: center;
    gap: 12px;
  }

  h2 .h-num {
    font-family: var(--mono);
    font-size: 13px;
    color: var(--accent);
    font-weight: 400;
    opacity: .7;
  }

  h3 {
    font-family: var(--sans);
    font-size: 16px;
    font-weight: 700;
    color: var(--white);
    letter-spacing: -.01em;
    margin: 28px 0 12px;
  }

  h4 {
    font-size: 12px;
    font-weight: 600;
    color: var(--accent2);
    letter-spacing: .1em;
    text-transform: uppercase;
    margin: 20px 0 8px;
  }

  p { color: var(--text); line-height: 1.75; margin-bottom: 14px; }

  /* ── DIVIDER ── */
  hr {
    border: none;
    border-top: 1px solid var(--border);
    margin: 32px 0;
  }

  /* ── CODE ── */
  code {
    font-family: var(--mono);
    font-size: 12.5px;
    background: rgba(0,212,255,.07);
    border: 1px solid rgba(0,212,255,.15);
    color: var(--accent);
    padding: 1px 6px;
    border-radius: 3px;
  }

  pre {
    background: var(--bg3);
    border: 1px solid var(--border);
    border-left: 3px solid var(--accent2);
    border-radius: 6px;
    padding: 20px 22px;
    overflow-x: auto;
    margin: 16px 0 24px;
    position: relative;
  }

  pre .pre-label {
    position: absolute;
    top: 10px; right: 14px;
    font-size: 10px;
    color: var(--text3);
    letter-spacing: .08em;
    text-transform: uppercase;
  }

  pre code {
    background: none;
    border: none;
    color: var(--text);
    font-size: 13px;
    padding: 0;
  }

  pre code .kw  { color: var(--purple); }
  pre code .fn  { color: var(--accent); }
  pre code .str { color: var(--green); }
  pre code .cm  { color: var(--text3); font-style: italic; }
  pre code .var { color: var(--yellow); }
  pre code .num { color: var(--red); }

  /* ── TABLES ── */
  .table-wrap {
    overflow-x: auto;
    margin: 16px 0 24px;
    border-radius: 6px;
    border: 1px solid var(--border);
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }

  thead tr {
    background: var(--bg3);
    border-bottom: 1px solid var(--border2);
  }

  thead th {
    padding: 11px 16px;
    text-align: left;
    font-weight: 600;
    font-size: 11px;
    letter-spacing: .08em;
    text-transform: uppercase;
    color: var(--text2);
    white-space: nowrap;
  }

  tbody tr {
    border-bottom: 1px solid var(--border);
    transition: background .1s;
  }

  tbody tr:last-child { border-bottom: none; }
  tbody tr:hover { background: rgba(255,255,255,.02); }

  td {
    padding: 10px 16px;
    vertical-align: top;
    color: var(--text);
  }

  td:first-child {
    font-family: var(--mono);
    font-size: 12.5px;
    color: var(--accent);
    white-space: nowrap;
  }

  /* ── CARDS ── */
  .card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 14px;
    margin: 20px 0;
  }

  .card {
    background: var(--bg2);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 18px 20px;
    transition: border-color .2s, transform .2s;
  }

  .card:hover {
    border-color: var(--border2);
    transform: translateY(-2px);
  }

  .card .card-icon {
    font-size: 22px;
    margin-bottom: 10px;
  }

  .card .card-title {
    font-family: var(--sans);
    font-size: 14px;
    font-weight: 700;
    color: var(--white);
    margin-bottom: 6px;
  }

  .card p { font-size: 12.5px; color: var(--text2); margin: 0; }

  /* ── REGION BLOCKS ── */
  .region-block {
    background: var(--bg2);
    border: 1px solid var(--border);
    border-radius: 6px;
    margin: 12px 0;
    overflow: hidden;
  }

  .region-header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 18px;
    background: var(--bg3);
    border-bottom: 1px solid var(--border);
  }

  .region-num {
    font-size: 10px;
    font-weight: 600;
    color: var(--accent2);
    letter-spacing: .1em;
    min-width: 24px;
  }

  .region-name {
    font-family: var(--mono);
    font-size: 13px;
    font-weight: 500;
    color: var(--accent);
  }

  .region-desc {
    font-size: 12px;
    color: var(--text2);
    margin-left: auto;
  }

  .region-body {
    padding: 14px 18px;
    font-size: 13px;
    color: var(--text2);
  }

  .region-body ul {
    list-style: none;
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    padding: 0;
  }

  .region-body ul li {
    background: rgba(0,212,255,.06);
    border: 1px solid rgba(0,212,255,.14);
    border-radius: 3px;
    padding: 2px 8px;
    font-size: 12px;
    color: var(--text);
  }

  /* ── CALLOUTS ── */
  .callout {
    display: flex;
    gap: 14px;
    padding: 14px 18px;
    border-radius: 6px;
    margin: 16px 0;
    font-size: 13px;
  }

  .callout-warn {
    background: rgba(255,211,42,.06);
    border: 1px solid rgba(255,211,42,.25);
    color: var(--yellow);
  }

  .callout-info {
    background: rgba(0,212,255,.06);
    border: 1px solid rgba(0,212,255,.2);
    color: var(--accent);
  }

  .callout-danger {
    background: rgba(255,71,87,.06);
    border: 1px solid rgba(255,71,87,.2);
    color: var(--red);
  }

  .callout-success {
    background: rgba(0,255,157,.06);
    border: 1px solid rgba(0,255,157,.2);
    color: var(--green);
  }

  .callout-icon { font-size: 16px; flex-shrink: 0; margin-top: 1px; }
  .callout p { color: inherit; margin: 0; }

  /* ── FLOW DIAGRAM ── */
  .flow {
    display: flex;
    flex-direction: column;
    gap: 0;
    margin: 20px 0;
  }

  .flow-step {
    display: flex;
    gap: 0;
    position: relative;
  }

  .flow-left {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 40px;
    flex-shrink: 0;
  }

  .flow-circle {
    width: 32px; height: 32px;
    border-radius: 50%;
    border: 2px solid var(--accent2);
    background: var(--bg2);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    font-weight: 700;
    color: var(--accent);
    flex-shrink: 0;
    z-index: 1;
  }

  .flow-line {
    width: 2px;
    flex: 1;
    min-height: 20px;
    background: var(--border2);
    margin: 0 auto;
  }

  .flow-step:last-child .flow-line { display: none; }

  .flow-content {
    padding: 4px 0 24px 16px;
    flex: 1;
  }

  .flow-title {
    font-family: var(--sans);
    font-weight: 700;
    font-size: 14px;
    color: var(--white);
    margin-bottom: 4px;
  }

  .flow-desc {
    font-size: 12.5px;
    color: var(--text2);
    line-height: 1.6;
  }

  .flow-sub {
    list-style: none;
    padding: 6px 0 0;
  }

  .flow-sub li {
    font-size: 12px;
    color: var(--text2);
    padding: 2px 0 2px 14px;
    position: relative;
  }

  .flow-sub li::before {
    content: '─';
    position: absolute;
    left: 0;
    color: var(--text3);
  }

  /* ── SEVERITY PILLS ── */
  .sev-high   { color: var(--red);    font-weight: 600; }
  .sev-med    { color: var(--yellow); font-weight: 600; }
  .sev-low    { color: var(--green);  font-weight: 600; }

  /* ── PARAM TABLE ── */
  .param-name { font-family: var(--mono); color: var(--accent); font-size: 12.5px; }
  .param-type { font-family: var(--mono); color: var(--purple); font-size: 12px; }

  /* ── FOOTER ── */
  footer {
    margin-top: 80px;
    padding: 28px 0;
    border-top: 1px solid var(--border);
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12px;
    color: var(--text3);
  }

  footer span { color: var(--text3); }

  /* ── SCROLLBAR (main) ── */
  ::-webkit-scrollbar { width: 6px; }
  ::-webkit-scrollbar-track { background: var(--bg); }
  ::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 3px; }
</style>
</head>
<body>

<div class="layout">

  <!-- ═══════════════════════════════════════════════════════════════ SIDEBAR -->
  <aside>
    <div class="sidebar-brand">
      <div class="tag">Documentação Técnica</div>
      <h1>AD Lockout<br>Monitor</h1>
      <span class="version">v2.0</span>
    </div>
    <nav>
      <div class="nav-section">Início</div>
      <a href="#overview" class="active">Visão Geral</a>
      <a href="#prereqs">Pré-requisitos</a>

      <div class="nav-section">Arquitetura</div>
      <a href="#estrutura">Estrutura do Script</a>
      <a href="#dados">Estrutura de Dados</a>
      <a href="#fluxo">Fluxo de Execução</a>

      <div class="nav-section">Referência</div>
      <a href="#helpers">Helpers de Interface</a>
      <a href="#analise">Get-SourceAnalysis</a>
      <a href="#format">Format-LockoutEvent</a>
      <a href="#stats">Show-StatsPanel</a>
      <a href="#monitor">Start-ADLockoutMonitor</a>
      <a href="#psremoting">PSRemoting</a>

      <div class="nav-section">Guias</div>
      <a href="#erros">Tratamento de Erros</a>
      <a href="#uso">Exemplos de Uso</a>
      <a href="#seguranca">Segurança</a>
    </nav>
  </aside>

  <!-- ═══════════════════════════════════════════════════════════════ MAIN -->
  <main>

    <!-- ── HERO ── -->
    <div class="hero" id="overview">
      <div class="hero-eyebrow">
        <div class="dot"></div>
        <span>Active Directory · PowerShell 5.1+</span>
      </div>
      <h1>AD <span>Lockout</span><br>Monitor</h1>
      <p>Script PowerShell para monitoramento em tempo real de eventos de bloqueio de conta (Event ID 4740) no Active Directory, com análise de origem, diagnóstico automático e estatísticas acumuladas de sessão.</p>
      <div class="badge-row">
        <span class="badge badge-blue">PSRemoting</span>
        <span class="badge badge-green">Event ID 4740</span>
        <span class="badge badge-purple">Multi-DC</span>
        <span class="badge badge-yellow">Tempo Real</span>
        <span class="badge badge-red">Diagnóstico Automático</span>
      </div>
    </div>

    <!-- ── OVERVIEW ── -->
    <section>
      <h2><span class="h-num">01</span> Visão Geral</h2>
      <p>O script opera por ciclos de 10 segundos, consultando simultaneamente todos os Domain Controllers do domínio via PSRemoting. Eventos são deduplicados por <code>DC + RecordId</code> e processados de forma incremental a cada ciclo. A cada 30 ciclos, um painel de estatísticas acumuladas é exibido automaticamente.</p>

      <div class="card-grid">
        <div class="card">
          <div class="card-icon">⚡</div>
          <div class="card-title">Tempo Real</div>
          <p>Ciclos de 10 s com polling paralelo em todos os DCs via PSRemoting.</p>
        </div>
        <div class="card">
          <div class="card-icon">🔍</div>
          <div class="card-title">Análise de Origem</div>
          <p>Classifica o dispositivo de origem em 5 categorias com severidade (Alta / Média / Baixa).</p>
        </div>
        <div class="card">
          <div class="card-icon">📊</div>
          <div class="card-title">Estatísticas</div>
          <p>Contadores por sessão, por DC, por usuário e janela deslizante de 60 min.</p>
        </div>
        <div class="card">
          <div class="card-icon">🛡️</div>
          <div class="card-title">Diagnóstico</div>
          <p>Detecta e categoriza erros de PSRemoting com sugestão de correção.</p>
        </div>
        <div class="card">
          <div class="card-icon">🎯</div>
          <div class="card-title">Filtro por Usuário</div>
          <p>Monitora todos os usuários ou filtra por uma conta específica.</p>
        </div>
        <div class="card">
          <div class="card-icon">♻️</div>
          <div class="card-title">Deduplicação</div>
          <p>HashSet garante que cada evento seja processado exatamente uma vez.</p>
        </div>
      </div>
    </section>

    <!-- ── PRÉ-REQUISITOS ── -->
    <section id="prereqs">
      <h2><span class="h-num">02</span> Pré-requisitos</h2>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Requisito</th>
              <th>Detalhe</th>
            </tr>
          </thead>
          <tbody>
            <tr><td>PowerShell</td><td>Versão 5.1 ou superior</td></tr>
            <tr><td>Módulo AD</td><td>ActiveDirectory (RSAT) — importado automaticamente se disponível</td></tr>
            <tr><td>Privilégio</td><td>Administrador de Domínio (leitura do log Security nos DCs)</td></tr>
            <tr><td>WinRM</td><td>PSRemoting habilitado em todos os DCs, portas 5985/5986 acessíveis</td></tr>
            <tr><td>DNS</td><td>Resolução de nomes dos DCs a partir da máquina de execução</td></tr>
          </tbody>
        </table>
      </div>
      <div class="callout callout-warn">
        <span class="callout-icon">⚠</span>
        <p>O script verifica automaticamente se está sendo executado como Administrador e encerra caso contrário.</p>
      </div>
    </section>

    <!-- ── ESTRUTURA ── -->
    <section id="estrutura">
      <h2><span class="h-num">03</span> Estrutura do Script</h2>
      <p>O código está organizado em 8 regiões delimitadas por <code>#region</code>/<code>#endregion</code>:</p>

      <div class="region-block">
        <div class="region-header">
          <span class="region-num">01</span>
          <span class="region-name">INICIALIZAÇÃO</span>
          <span class="region-desc">Bootstrap</span>
        </div>
        <div class="region-body">
          <ul><li>Import-Module ActiveDirectory</li><li>$DCs (todos os DCs)</li><li>$cacheDns</li><li>$script:Stats</li></ul>
        </div>
      </div>

      <div class="region-block">
        <div class="region-header">
          <span class="region-num">02</span>
          <span class="region-name">HELPERS DE INTERFACE</span>
          <span class="region-desc">UI Console</span>
        </div>
        <div class="region-body">
          <ul><li>Write-Separator</li><li>Write-Header</li><li>Write-StatusBar</li><li>Write-KeyValue</li><li>Write-Badge</li></ul>
        </div>
      </div>

      <div class="region-block">
        <div class="region-header">
          <span class="region-num">03</span>
          <span class="region-name">ANÁLISE DE ORIGEM</span>
          <span class="region-desc">Classificação</span>
        </div>
        <div class="region-body">
          <ul><li>Get-SourceAnalysis</li><li>Cache DNS por sessão</li><li>Switch por regex (5 categorias)</li></ul>
        </div>
      </div>

      <div class="region-block">
        <div class="region-header">
          <span class="region-num">04</span>
          <span class="region-name">FORMATAÇÃO DE EVENTOS</span>
          <span class="region-desc">Renderização de alertas</span>
        </div>
        <div class="region-body">
          <ul><li>Format-LockoutEvent</li><li>Badge de severidade</li><li>Campos principais + diagnóstico</li></ul>
        </div>
      </div>

      <div class="region-block">
        <div class="region-header">
          <span class="region-num">05</span>
          <span class="region-name">PAINEL DE ESTATÍSTICAS</span>
          <span class="region-desc">Resumo acumulado</span>
        </div>
        <div class="region-body">
          <ul><li>Show-StatsPanel</li><li>Fila deslizante de 60 min</li><li>Top 3 usuários</li></ul>
        </div>
      </div>

      <div class="region-block">
        <div class="region-header">
          <span class="region-num">06</span>
          <span class="region-name">TELA DE SELEÇÃO</span>
          <span class="region-desc">Menu interativo</span>
        </div>
        <div class="region-body">
          <ul><li>Get-MonitoringChoice</li><li>Modo: Todos / Específico</li></ul>
        </div>
      </div>

      <div class="region-block">
        <div class="region-header">
          <span class="region-num">07</span>
          <span class="region-name">MONITORAMENTO PRINCIPAL</span>
          <span class="region-desc">Loop de polling</span>
        </div>
        <div class="region-body">
          <ul><li>Start-ADLockoutMonitor</li><li>Invoke-Command remoto</li><li>Deduplicação por HashSet</li><li>Ciclos de 10 s</li></ul>
        </div>
      </div>

      <div class="region-block">
        <div class="region-header">
          <span class="region-num">08</span>
          <span class="region-name">PRÉ-REQUISITOS / PSREMOTING</span>
          <span class="region-desc">Diagnóstico e setup</span>
        </div>
        <div class="region-body">
          <ul><li>Test-PSRemotingAvailability</li><li>Show-PSRemotingDiagnostics</li><li>Show-PSRemotingInstructions</li><li>Enable-PSRemotingOnDCs</li></ul>
        </div>
      </div>
    </section>

    <!-- ── DADOS ── -->
    <section id="dados">
      <h2><span class="h-num">04</span> Estrutura de Dados</h2>

      <h3>$script:Stats</h3>
      <p>Hashtable global de sessão inicializado na região INICIALIZAÇÃO. Persiste durante toda a execução do script.</p>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Chave</th><th>Tipo</th><th>Descrição</th></tr></thead>
          <tbody>
            <tr><td>TotalBloqueios</td><td><span class="param-type">Int</span></td><td>Contador acumulado de eventos únicos na sessão</td></tr>
            <tr><td>UltimaHora</td><td><span class="param-type">Queue&lt;DateTime&gt;</span></td><td>Fila de timestamps — base para contagem dos últimos 60 min</td></tr>
            <tr><td>BloqueiosPorDC</td><td><span class="param-type">Hashtable</span></td><td>Chave = nome do DC; valor = total de bloqueios registrados</td></tr>
            <tr><td>BloqueiosPorUser</td><td><span class="param-type">Hashtable</span></td><td>Chave = username; valor = total de bloqueios do usuário</td></tr>
            <tr><td>CicloAtual</td><td><span class="param-type">Int</span></td><td>Número do ciclo em execução no momento</td></tr>
            <tr><td>Inicio</td><td><span class="param-type">DateTime</span></td><td>Timestamp de início do monitoramento (para cálculo de uptime)</td></tr>
          </tbody>
        </table>
      </div>

      <h3>$cacheDns</h3>
      <p>Hashtable de escopo de script. Armazena <code>CallerComputer → IP</code> de cada dispositivo já processado, evitando chamadas repetidas ao DNS. Valor é <code>$null</code> se a resolução falhar.</p>

      <h3>$processedEvents</h3>
      <p>HashSet&lt;String&gt; contendo IDs de eventos já processados no formato <code>"NomeDC-RecordId"</code>. Garante que um evento não seja exibido mais de uma vez entre ciclos consecutivos.</p>
    </section>

    <!-- ── FLUXO ── -->
    <section id="fluxo">
      <h2><span class="h-num">05</span> Fluxo de Execução</h2>
      <div class="flow">
        <div class="flow-step">
          <div class="flow-left"><div class="flow-circle">1</div><div class="flow-line"></div></div>
          <div class="flow-content">
            <div class="flow-title">Verificação de privilégio</div>
            <div class="flow-desc">Checa se o processo atual tem role de Administrador. Encerra com mensagem se não tiver.</div>
          </div>
        </div>
        <div class="flow-step">
          <div class="flow-left"><div class="flow-circle">2</div><div class="flow-line"></div></div>
          <div class="flow-content">
            <div class="flow-title">Test-PSRemotingAvailability</div>
            <div class="flow-desc">Executa <code>Test-WSMan</code> em cada DC detectado. Se algum falhar, exibe menu de diagnóstico:</div>
            <ul class="flow-sub">
              <li>[1] Diagnóstico completo de PSRemoting</li>
              <li>[2] Habilitar PSRemoting automaticamente</li>
              <li>[3] Sair</li>
            </ul>
          </div>
        </div>
        <div class="flow-step">
          <div class="flow-left"><div class="flow-circle">3</div><div class="flow-line"></div></div>
          <div class="flow-content">
            <div class="flow-title">Get-MonitoringChoice</div>
            <div class="flow-desc">Exibe menu de seleção de modo: monitorar todos os usuários ou filtrar por usuário específico.</div>
          </div>
        </div>
        <div class="flow-step">
          <div class="flow-left"><div class="flow-circle">4</div><div class="flow-line"></div></div>
          <div class="flow-content">
            <div class="flow-title">Loop principal (Start-ADLockoutMonitor)</div>
            <div class="flow-desc">Ciclo de 10 segundos repetido até Ctrl+C ou 3 falhas consecutivas:</div>
            <ul class="flow-sub">
              <li>Invoke-Command paralelo em todos os DCs — coleta eventos 4740</li>
              <li>Deduplica por HashSet → filtra usuário → atualiza $script:Stats</li>
              <li>Format-LockoutEvent para cada evento novo</li>
              <li>A cada 30 ciclos → Show-StatsPanel</li>
              <li>Erro de PSRemoting → diagnóstico + incrementa failCount</li>
              <li>failCount ≥ 3 → encerra o loop</li>
              <li>Start-Sleep 10 s → próximo ciclo</li>
            </ul>
          </div>
        </div>
        <div class="flow-step">
          <div class="flow-left"><div class="flow-circle">5</div><div class="flow-line"></div></div>
          <div class="flow-content">
            <div class="flow-title">Encerramento</div>
            <div class="flow-desc">Exibe separador "SESSÃO ENCERRADA" seguido do painel de estatísticas final.</div>
          </div>
        </div>
      </div>
    </section>

    <!-- ── HELPERS ── -->
    <section id="helpers">
      <h2><span class="h-num">06</span> Helpers de Interface</h2>
      <p>Funções utilitárias que compõem a UI do console. Todas usam <code>Write-Host</code> com parâmetros de cor.</p>

      <h3>Write-Separator</h3>
      <p>Exibe uma linha horizontal de largura configurável.</p>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Parâmetro</th><th>Tipo</th><th>Padrão</th><th>Descrição</th></tr></thead>
          <tbody>
            <tr><td>-Char</td><td><span class="param-type">String</span></td><td><code>'─'</code></td><td>Caractere repetido</td></tr>
            <tr><td>-Width</td><td><span class="param-type">Int</span></td><td><code>72</code></td><td>Largura em caracteres</td></tr>
            <tr><td>-Color</td><td><span class="param-type">ConsoleColor</span></td><td><code>DarkGray</code></td><td>Cor de exibição</td></tr>
          </tbody>
        </table>
      </div>

      <h3>Write-Header</h3>
      <p>Renderiza uma caixa com borda dupla (╔═╗) de 72 caracteres centralizada, com título e subtítulo opcionais.</p>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Parâmetro</th><th>Tipo</th><th>Descrição</th></tr></thead>
          <tbody>
            <tr><td>-Title</td><td><span class="param-type">String</span></td><td>Título principal (cor Cyan)</td></tr>
            <tr><td>-Subtitle</td><td><span class="param-type">String</span></td><td>Subtítulo opcional (cor DarkCyan)</td></tr>
          </tbody>
        </table>
      </div>

      <h3>Write-StatusBar</h3>
      <p>Exibe uma linha de status com timestamp <code>[HH:mm:ss]</code> prefixado e mensagem colorida.</p>

      <h3>Write-KeyValue</h3>
      <p>Exibe um par chave–valor em duas colunas, com largura de chave configurável (padrão 22 caracteres).</p>

      <h3>Write-Badge</h3>
      <p>Imprime um rótulo com fundo sólido colorido — usado para indicar severidade do bloqueio (CRÍTICO / DETECTADO / REGISTRADO).</p>
    </section>

    <!-- ── ANÁLISE ── -->
    <section id="analise">
      <h2><span class="h-num">07</span> Get-SourceAnalysis</h2>
      <p>Classifica o dispositivo <code>CallerComputer</code> do evento 4740 em uma de cinco categorias, resolvendo seu endereço IP via DNS com cache em memória.</p>

      <h4>Parâmetro</h4>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Parâmetro</th><th>Tipo</th><th>Descrição</th></tr></thead>
          <tbody>
            <tr><td>-CallerComputer</td><td><span class="param-type">String</span></td><td>Nome do dispositivo de origem do Event ID 4740 (Properties[3])</td></tr>
          </tbody>
        </table>
      </div>

      <h4>Retorno</h4>
      <p>Hashtable com as chaves: <code>IP</code>, <code>Icone</code>, <code>Tipo</code>, <code>Suspeita</code>, <code>Sev</code></p>

      <h4>Tabela de classificação</h4>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Padrão (Regex)</th><th>Ícone</th><th>Tipo</th><th>Sev</th><th>Diagnóstico</th></tr></thead>
          <tbody>
            <tr>
              <td>(vazio / "-")</td>
              <td>[?]</td>
              <td>Origem Oculta</td>
              <td><span class="sev-med">Med</span></td>
              <td>Celular via ActiveSync, RADIUS/NPS ou mapeamento externo</td>
            </tr>
            <tr>
              <td>EXCH|MAIL|OWA|WEB</td>
              <td>[M]</td>
              <td>Servidor E-mail/Web</td>
              <td><span class="sev-med">Med</span></td>
              <td>Senha desatualizada em dispositivo móvel (ActiveSync)</td>
            </tr>
            <tr>
              <td>DC0|AD0|SRV-AD</td>
              <td>[D]</td>
              <td>Domain Controller</td>
              <td><span class="sev-med">Med</span></td>
              <td>Autenticação direta; verificar Wi-Fi (NPS), VPN ou scripts</td>
            </tr>
            <tr>
              <td>VPN|FW|FIREWALL</td>
              <td>[!]</td>
              <td>Gateway / VPN</td>
              <td><span class="sev-high">High</span></td>
              <td>Conexão externa; possível ataque de força bruta</td>
            </tr>
            <tr>
              <td>FS|FILE|ARQUIVO</td>
              <td>[F]</td>
              <td>File Server</td>
              <td><span class="sev-low">Low</span></td>
              <td>Mapeamento de rede com credenciais antigas</td>
            </tr>
            <tr>
              <td>(default)</td>
              <td>[W]</td>
              <td>Estação de Trabalho</td>
              <td><span class="sev-low">Low</span></td>
              <td>Verificar Gerenciador de Credenciais ou Tarefas Agendadas</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="callout callout-info">
        <span class="callout-icon">ℹ</span>
        <p>O cache DNS (<code>$cacheDns</code>) é consultado antes de chamar <code>Resolve-DnsName</code>, evitando latência em eventos repetidos do mesmo dispositivo.</p>
      </div>
    </section>

    <!-- ── FORMAT-LOCKOUTEVENT ── -->
    <section id="format">
      <h2><span class="h-num">08</span> Format-LockoutEvent</h2>
      <p>Renderiza o alerta completo no console para um evento de bloqueio detectado.</p>

      <div class="table-wrap">
        <table>
          <thead><tr><th>Parâmetro</th><th>Tipo</th><th>Descrição</th></tr></thead>
          <tbody>
            <tr><td>-Evento</td><td><span class="param-type">PSCustomObject</span></td><td>Objeto retornado pelo Invoke-Command remoto</td></tr>
            <tr><td>-TargetUserName</td><td><span class="param-type">String</span></td><td>Usuário bloqueado (Properties[0] do evento 4740)</td></tr>
            <tr><td>-CallerComputer</td><td><span class="param-type">String</span></td><td>Dispositivo de origem (Properties[3] do evento 4740)</td></tr>
            <tr><td>-DCNome</td><td><span class="param-type">String</span></td><td>Nome do DC que registrou o evento</td></tr>
          </tbody>
        </table>
      </div>

      <h4>Estrutura do alerta exibido</h4>
      <pre><code><span class="cm">═══════════════════════════════════════════════════════</span>
<span class="str"> BLOQUEIO CRÍTICO </span>  <span class="cm">&lt;-- badge colorido por severidade</span>
<span class="cm">───────────────────────────────────────────────────────</span>
  <span class="kw">Usuário</span>              joao.silva
  <span class="kw">Data / Hora</span>          17/03/2025  14:32:01
  <span class="kw">Domain Controller</span>    DC01
<span class="cm">···············································</span>
  <span class="kw">Disp. de Origem</span>      [!] VPN-GW01
  <span class="kw">Tipo de Origem</span>       Gateway / VPN
  <span class="kw">IP Resolvido</span>         10.0.0.254
<span class="cm">···············································</span>
  <span class="kw">Diagnóstico</span>          Tentativa de conexão externa. Possível ataque de força bruta.
<span class="cm">═══════════════════════════════════════════════════════</span></code></pre>
    </section>

    <!-- ── STATS ── -->
    <section id="stats">
      <h2><span class="h-num">09</span> Show-StatsPanel</h2>
      <p>Exibe um painel com borda em caixa (┌─┐) contendo estatísticas acumuladas da sessão. Chamado automaticamente a cada 30 ciclos e ao encerrar a sessão.</p>

      <h4>Conteúdo exibido</h4>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Campo</th><th>Fonte</th><th>Cor</th></tr></thead>
          <tbody>
            <tr><td>Tempo de execução</td><td><code>(Get-Date) - $script:Stats.Inicio</code></td><td>White</td></tr>
            <tr><td>Ciclos executados</td><td><code>$script:Stats.CicloAtual</code></td><td>Cyan</td></tr>
            <tr><td>Total de bloqueios</td><td><code>$script:Stats.TotalBloqueios</code></td><td>Red</td></tr>
            <tr><td>Última hora</td><td>Fila após limpeza de entradas &gt; 60 min</td><td>Yellow</td></tr>
            <tr><td>DCs monitorados</td><td><code>$DCs -join ', '</code></td><td>DarkCyan</td></tr>
            <tr><td>Bloqueios por DC</td><td><code>$script:Stats.BloqueiosPorDC</code> (se Total &gt; 0)</td><td>Magenta</td></tr>
            <tr><td>Top 3 usuários</td><td><code>$script:Stats.BloqueiosPorUser</code> ordenado desc (se Total &gt; 0)</td><td>Yellow</td></tr>
          </tbody>
        </table>
      </div>

      <div class="callout callout-info">
        <span class="callout-icon">ℹ</span>
        <p>A limpeza da fila <code>UltimaHora</code> ocorre no início de cada chamada a <code>Show-StatsPanel</code>, removendo timestamps com mais de 60 minutos.</p>
      </div>
    </section>

    <!-- ── MONITOR ── -->
    <section id="monitor">
      <h2><span class="h-num">10</span> Start-ADLockoutMonitor</h2>
      <p>Função principal. Executa o loop de monitoramento até Ctrl+C ou 3 falhas consecutivas de PSRemoting.</p>

      <h4>Parâmetro</h4>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Parâmetro</th><th>Tipo</th><th>Descrição</th></tr></thead>
          <tbody>
            <tr><td>-MonitoringChoice</td><td><span class="param-type">Hashtable</span></td><td>Retornado por <code>Get-MonitoringChoice</code> — chaves <code>Tipo</code> e <code>Usuario</code></td></tr>
          </tbody>
        </table>
      </div>

      <h4>Script Block Remoto</h4>
      <p>Executado via <code>Invoke-Command -ComputerName $DCs</code> em paralelo. Coleta eventos do log Security com <code>Get-WinEvent -FilterHashtable</code> e retorna um <code>PSCustomObject</code> por evento:</p>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Campo</th><th>Fonte</th></tr></thead>
          <tbody>
            <tr><td>RecordId</td><td>Identificador único do evento no log do DC</td></tr>
            <tr><td>TimeCreated</td><td>Timestamp do evento</td></tr>
            <tr><td>TargetUserName</td><td><code>$evt.Properties[0].Value</code></td></tr>
            <tr><td>CallerComputer</td><td><code>$evt.Properties[3].Value</code></td></tr>
            <tr><td>OrigemDC</td><td><code>$env:COMPUTERNAME</code> (contexto remoto)</td></tr>
          </tbody>
        </table>
      </div>

      <h4>Variáveis de Configuração</h4>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Variável / Linha</th><th>Valor Padrão</th><th>Efeito</th></tr></thead>
          <tbody>
            <tr><td>$lastChecked</td><td><code>Now - 7 dias</code></td><td>Janela inicial de busca (captura eventos retroativos)</td></tr>
            <tr><td>Start-Sleep</td><td>10 segundos</td><td>Intervalo entre ciclos</td></tr>
            <tr><td>ciclo % 30</td><td>30 ciclos</td><td>Frequência do painel de resumo</td></tr>
            <tr><td>$failureCount</td><td>3 tentativas</td><td>Máximo de falhas antes de encerrar</td></tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ── PSREMOTING ── -->
    <section id="psremoting">
      <h2><span class="h-num">11</span> Funções de PSRemoting</h2>

      <h3>Test-PSRemotingAvailability</h3>
      <p>Testa <code>Test-WSMan</code> em cada DC e retorna um objeto com <code>Disponivel</code> (bool) e <code>Detalhes</code> (array com status por DC). Em caso de falha, classifica a causa por regex na mensagem de exceção.</p>

      <h3>Show-PSRemotingDiagnostics</h3>
      <p>Diagnóstico completo em 5 etapas:</p>
      <div class="table-wrap">
        <table>
          <thead><tr><th>#</th><th>Verificação</th><th>Comando</th></tr></thead>
          <tbody>
            <tr><td>1</td><td>Serviço WinRM local</td><td><code>Get-Service -Name WinRM</code></td></tr>
            <tr><td>2</td><td>WSMan em cada DC</td><td><code>Test-WSMan -ComputerName $dc</code></td></tr>
            <tr><td>3</td><td>Trusted Hosts</td><td><code>Get-Item WSMan:\localhost\Client\TrustedHosts</code></td></tr>
            <tr><td>4</td><td>Portas 5985/5986</td><td><code>Test-NetConnection -Port 5985/5986</code></td></tr>
            <tr><td>5</td><td>SO + versão do PS</td><td><code>[Environment]::OSVersion</code> / <code>$PSVersionTable</code></td></tr>
          </tbody>
        </table>
      </div>

      <h3>Enable-PSRemotingOnDCs</h3>
      <p>Executa <code>Enable-PSRemoting -Force -SkipNetworkProfileCheck</code> via <code>Invoke-Command</code> em cada DC. Exibe status individual por DC.</p>

      <pre><span class="pre-label">PowerShell</span><code><span class="cm"># Habilitar manualmente em cada DC (como Administrador):</span>
<span class="fn">Enable-PSRemoting</span> -Force -SkipNetworkProfileCheck

<span class="cm"># Ou remotamente de um único host:</span>
<span class="var">$DCs</span> = <span class="fn">@</span>(<span class="str">'DC01'</span>, <span class="str">'DC02'</span>)
<span class="var">$DCs</span> | <span class="fn">ForEach-Object</span> {
    <span class="fn">Invoke-Command</span> -ComputerName <span class="var">$_</span> -ScriptBlock {
        <span class="fn">Enable-PSRemoting</span> -Force -SkipNetworkProfileCheck
    }
}</code></pre>
    </section>

    <!-- ── ERROS ── -->
    <section id="erros">
      <h2><span class="h-num">12</span> Tratamento de Erros de PSRemoting</h2>
      <p>O bloco <code>catch</code> de <code>Start-ADLockoutMonitor</code> categoriza automaticamente as exceções por regex na mensagem de erro:</p>

      <div class="table-wrap">
        <table>
          <thead><tr><th>Padrão na Mensagem</th><th>Diagnóstico</th><th>Sugestão</th></tr></thead>
          <tbody>
            <tr>
              <td>timeout | WinRM | timed out</td>
              <td>Timeout de comunicação</td>
              <td>Verificar ping/telnet 5985; aumentar <code>-OperationTimeoutSec</code>; checar WinRM</td>
            </tr>
            <tr>
              <td>Access Denied | Unauthorized</td>
              <td>Credenciais insuficientes</td>
              <td>Executar como Admin de Domínio; verificar <code>TrustedHosts</code></td>
            </tr>
            <tr>
              <td>WinRM não está | not connected</td>
              <td>WinRM desabilitado no DC</td>
              <td><code>Enable-PSRemoting -Force</code> no DC; verificar firewall; <code>Restart-Service WinRM</code></td>
            </tr>
            <tr>
              <td>firewall | port</td>
              <td>Bloqueio de firewall</td>
              <td>Liberar portas 5985/5986; <code>Test-NetConnection -Port 5985</code></td>
            </tr>
            <tr>
              <td>host | DNS | não encontrado</td>
              <td>Falha de resolução DNS</td>
              <td><code>nslookup</code> no DC; usar FQDN ou IP; checar <code>Get-DnsClientServerAddress</code></td>
            </tr>
            <tr>
              <td>(default)</td>
              <td>Erro não categorizado</td>
              <td>Verificar WinRM e conectividade de rede</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="callout callout-danger">
        <span class="callout-icon">✖</span>
        <p>Após 3 falhas consecutivas (<code>$failureCount ≥ 3</code>), o loop é encerrado com <code>break</code> e o painel de estatísticas final é exibido.</p>
      </div>
    </section>

    <!-- ── USO ── -->
    <section id="uso">
      <h2><span class="h-num">13</span> Exemplos de Uso</h2>

      <h3>Execução Padrão</h3>
      <p>Abra o PowerShell como Administrador e execute:</p>
      <pre><span class="pre-label">PowerShell</span><code><span class="fn">.\ADLockoutMonitor.ps1</span></code></pre>

      <h3>Monitorar Todos os Usuários</h3>
      <p>Na tela de seleção, escolha <code>[1]</code>. Todos os bloqueios de qualquer conta serão exibidos.</p>

      <h3>Monitorar Usuário Específico</h3>
      <p>Na tela de seleção, escolha <code>[2]</code> e informe o nome de usuário (ex.: <code>francisco.silva</code>). Apenas bloqueios dessa conta serão exibidos — mas as estatísticas globais continuam sendo coletadas para todos os usuários.</p>

      <h3>Habilitar PSRemoting Automaticamente</h3>
      <p>Se o WinRM não estiver habilitado nos DCs, o script detecta a falha e oferece a opção <code>[2]</code> para executar <code>Enable-PSRemoting -Force</code> remotamente em todos os DCs.</p>

      <div class="callout callout-success">
        <span class="callout-icon">✔</span>
        <p>Pressione <code>Ctrl+C</code> a qualquer momento para encerrar o monitoramento. O painel de estatísticas final será exibido automaticamente.</p>
      </div>
    </section>

    <!-- ── SEGURANÇA ── -->
    <section id="seguranca">
      <h2><span class="h-num">14</span> Segurança</h2>

      <div class="callout callout-warn">
        <span class="callout-icon">🔒</span>
        <p>Execute apenas em ambientes controlados, com credenciais dedicadas de monitoramento. O acesso ao log de Segurança dos DCs é altamente privilegiado.</p>
      </div>

      <div class="table-wrap">
        <table>
          <thead><tr><th>Aspecto</th><th>Detalhe</th></tr></thead>
          <tbody>
            <tr>
              <td>Permissões mínimas</td>
              <td>Membro de "Event Log Readers" + permissão de PSRemoting nos DCs</td>
            </tr>
            <tr>
              <td>Sem escrita</td>
              <td>O script apenas lê eventos e não modifica nenhum objeto do AD</td>
            </tr>
            <tr>
              <td>Cache DNS</td>
              <td>Mantido apenas em memória durante a sessão — sem persistência em disco</td>
            </tr>
            <tr>
              <td>HashSet de eventos</td>
              <td>Cresce ao longo da sessão; em ambientes com alto volume, reiniciar periodicamente</td>
            </tr>
            <tr>
              <td>PSRemoting</td>
              <td>Usar credenciais com menor privilégio possível; considerar <code>JEA</code> (Just Enough Administration)</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <footer>
      <span>AD Lockout Monitor v2.0 — Documentação Técnica</span>
      <span>PowerShell · Active Directory · PSRemoting</span>
    </footer>

  </main>
</div>

<script>
  // Active nav highlight on scroll
  const sections = document.querySelectorAll('section[id], div[id]');
  const navLinks  = document.querySelectorAll('nav a');

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        navLinks.forEach(a => a.classList.remove('active'));
        const active = document.querySelector(`nav a[href="#${entry.target.id}"]`);
        if (active) active.classList.add('active');
      }
    });
  }, { threshold: 0.25, rootMargin: '-80px 0px -60% 0px' });

  sections.forEach(s => observer.observe(s));
</script>
</body>
</html>
