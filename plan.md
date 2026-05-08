# Plan: AgroPulse

> Documento de plano conceitual do projeto. Não contém código: descreve **o que** cada etapa faz, **por que** existe e **boas práticas** que orientam cada decisão. O leitor-alvo é o próprio autor (revisão pessoal) e a banca de Economia (defesa).

---

## 1. O problema econômico

### 1.1. Contexto

A pecuária de corte brasileira opera sob ciclos longos (de 24 a 36 meses do nascimento ao abate). A fase de **terminação em confinamento** (últimos 90 a 120 dias, com alimentação intensiva à base de milho e farelo de soja) concentra a maior parte do custo variável e é a única janela em que o pecuarista tem controle direto sobre o *trade-off* entre **ganho de peso adicional** e **custo do capital empatado**.

A decisão que orienta todo o ciclo financeiro do confinador é simples na superfície, mas combina três fontes de incerteza:

> *"A margem esperada por confinar mais um dia compensa o custo marginal de alimentação somado ao custo de oportunidade do capital?"*

### 1.2. O *cattle crush spread*

O conceito é análogo ao *crack spread* do refino de petróleo (diferença entre o preço do barril e a soma ponderada da gasolina e diesel produzidos a partir dele) e ao *soybean crush* da indústria de esmagamento (diferença entre o grão de soja e a soma ponderada do óleo e farelo). No caso bovino, a decomposição é:

- **Receita marginal:** preço do boi gordo (CEPEA/BGI) × peso de carcaça produzido.
- **Custo direto:** preço do milho × consumo + preço do farelo × consumo + outros (suplementos, mão-de-obra, sanidade); esses últimos podem entrar como parâmetro fixo ou ser estimados a partir de literatura aplicada.
- **Custo de oportunidade:** taxa Selic × capital total empatado × duração do confinamento.

O AgroPulse calcula essa margem em **base diária**, com cada componente isolado, permitindo análise contrafactual: *o que aconteceu primeiro, o boi caiu ou o milho subiu?*

### 1.3. Por que isso é interessante para a banca

- **Decisão real, mensurável:** não é um exercício acadêmico, e sim a métrica que rege bilhões em capital de giro de frigoríficos e *traders*.
- **Gap de ferramenta pública:** o cálculo existe internamente em todos os grandes *players*, mas não há observatório público no Brasil. O TCC entrega valor além do exercício acadêmico.
- **Conexão com teoria:** custo de oportunidade (microeconomia), risco de base e *hedge* (finanças), cointegração de séries (econometria).

---

## 2. Variáveis e fontes (justificativa econômica)

| Variável                | Fonte         | Papel teórico                                                | Frequência       |
|-------------------------|---------------|--------------------------------------------------------------|------------------|
| Indicador boi gordo     | CEPEA         | Receita à vista por arroba                                   | Diária           |
| Indicador milho         | CEPEA         | Custo alimentar (energia)                                    | Diária           |
| Indicador farelo de soja| CEPEA         | Custo alimentar (proteína)                                   | Diária           |
| Futuro BGI              | B3            | Expectativa de preço do mercado e instrumento de *hedge*     | Diária (ajuste)  |
| Selic                   | BCB / SGS     | Custo de oportunidade do capital de baixo risco              | Diária           |
| USD/BRL (PTAX)          | BCB / SGS     | Paridade de exportação e variável macro de controle          | Diária           |

**Boa prática econômica:** sempre documentar a frequência da série, o regime de divulgação (defasagem), a unidade e a metodologia da fonte. A banca pergunta isso.

---

## 3. Visão geral da arquitetura de dados

O pipeline implementa o padrão **medallion** (bronze / silver / gold), consagrado em engenharia de dados moderna. Cada camada tem um propósito distinto e regras de imutabilidade próprias.

| Camada    | Conteúdo                                              | Regra de imutabilidade                           |
|-----------|-------------------------------------------------------|--------------------------------------------------|
| Bronze    | Réplica fiel do dado bruto da fonte (CSV, JSON, HTML) | **Imutável.** Nunca sobrescrever, apenas anexar  |
| Silver    | Dado limpo, tipado, deduplicado, em Parquet           | Idempotente: reprocessável sem alterar o bronze  |
| Gold      | Métricas de negócio prontas para consumo              | Idempotente: rederivado das *silver*             |

**Princípio orientador:** se a banca questionar qualquer número no *gold*, deve ser possível navegar até a linha original do CSV no *bronze*. Essa é a base da auditabilidade.

---

## 4. Etapas de execução

### Etapa 1: Infraestrutura como código (Terraform + OCI)

**Objetivo:** provisionar VCN, *buckets* de Object Storage (bronze/silver/gold), IAM e *remote state*, tudo declarativo e reprodutível.

**Boas práticas:**

- **Estado remoto desde o primeiro dia.** Nunca commitar `.tfstate` no Git. O estado vai num *bucket* separado, com versionamento ativo.
- **Separar ambientes via *workspaces* ou diretórios.** Mesmo num TCC, manter `dev` e `prod` separados ensina o padrão correto.
- **Princípio do menor privilégio em IAM.** Cada serviço (ingestão, processamento, API) recebe credenciais que só permitem o que ele precisa. Evite a tentação de criar uma chave "admin" para tudo.
- **Lifecycle policies no bronze.** Custo de storage cresce silenciosamente. Definir regras de transição (ex.: arquivos com mais de 90 dias migram para *infrequent access*) desde o começo.
- **Tags em todos os recursos.** Incluir `project=agropulse` e `env=dev|prod`. Facilita auditoria de custo.

**O que aprender aqui:** ciclo `init → plan → apply`, módulos Terraform, gerenciamento de *secrets* via variáveis de ambiente (nunca hardcoded).

---

### Etapa 2: Ingestão (Python)

**Objetivo:** *scrapers* tipados para CEPEA, B3 e BCB que validam o dado, persistem o bruto no *bronze* e geram metadados de auditoria.

**Boas práticas:**

- **Arquitetura hexagonal (ports & adapters).** Cada fonte é um *adapter* que satisfaz uma interface única (`DataSource`). O *use case* de ingestão não sabe se está pegando CEPEA ou BCB; pede o dado por contrato. Isso permite testar offline e trocar fontes sem reescrever a lógica.
- **Validação *fail-fast* com Pydantic.** Dado malformado deve quebrar o *job* antes de tocar o *bronze*. Um *bronze* poluído é dívida técnica permanente.
- **Idempotência.** Re-rodar o *job* duas vezes para o mesmo dia não pode duplicar dado. Use chaves naturais (data + fonte + indicador) e particionamento determinístico.
- **Particionamento por data desde o início.** Estrutura de pastas `bronze/<fonte>/<indicador>/dt=YYYY-MM-DD/`. Facilita reprocessamento parcial e *time travel* manual.
- **Retry com *backoff* exponencial.** Sites públicos caem. *Backoff* exponencial com *jitter* evita marteladas e quebra de etiqueta com a fonte.
- ***Logging* estruturado.** Logs em JSON, com `trace_id` por execução. Quando algo der errado às 3 da manhã, o futuro-você agradece.
- **Metadados de proveniência.** Junto com o dado, persistir: URL de origem, *timestamp* da coleta, *hash* do conteúdo, versão do *parser*. Fundamental para reprodutibilidade científica.
- **Separar entrada (driving) de saída (driven).** O *scraper* (entrada) e o *uploader* para OCI (saída) são *adapters* distintos. Em testes, ambos viram *fakes* em memória.

**O que aprender aqui:** `Protocol` do Python (PEP 544), `pydantic-settings` para configuração, *dependency injection* manual no *composition root*.

---

### Etapa 3: Processamento medallion (Databricks + Delta Lake)

**Objetivo:** transformar *bronze → silver → gold*, calculando a margem de confinamento e sua decomposição.

#### Bronze → Silver (limpeza e tipagem)

**Boas práticas:**

- **Schema enforcement.** Delta Lake permite declarar e travar *schemas*. Use isso. Mudança de *schema* é evento explícito, não acidental.
- **Tipos canônicos.** Padronize unidades (R\$/@ × R\$/saca de 60kg), *timezone* (`America/Sao_Paulo`), formato de data (`YYYY-MM-DD`). Documente em uma tabela de metadados.
- **Deduplicação determinística.** Defina a chave natural por fonte e use `MERGE` para *upsert* idempotente.
- ***Quality checks* explícitos.** Para cada série, defina e teste invariantes: "preço do boi nunca é negativo", "Selic está em [0%, 20%]", "não existe gap maior que 5 dias úteis". Falha desses *checks* gera alerta, não silêncio.

#### Silver → Gold (modelagem econômica)

**Boas práticas:**

- **Cálculo da margem isolado por componente.** Não materialize só o número final. Materialize: receita, custo alimentar, custo de oportunidade, em colunas separadas. Permite decomposição na visualização.
- **Versionamento via Delta *time travel*.** Quando a metodologia mudar (ex.: substituir Selic por CDI), o histórico antigo continua acessível.
- **Não recalcular tudo a cada dia.** *Incremental processing*: processe apenas as partições novas, com *watermark* explícito.
- **Documentar premissas no nome da coluna ou em metadados.** `margem_bruta_diaria_brl_arroba_v1` é melhor que `margem`.

**O que aprender aqui:** Delta Lake (ACID, *time travel*, `MERGE`), particionamento e *Z-ordering*, padrões de *slowly changing dimensions* aplicados a séries temporais.

---

### Etapa 4: *Compute* para a API (Terraform)

**Objetivo:** instância OCI mínima (Always Free) com *firewall*, *systemd* e *reverse proxy*.

**Boas práticas:**

- **Tudo via Terraform.** Nada de SSH manual e instalação à mão. Se você não consegue destruir e recriar a máquina em 5 minutos, perdeu o jogo.
- ***Cloud-init* para *bootstrap*.** Configuração inicial declarativa, versionada no Git.
- **Health check exposto.** Endpoint `/health` simples, monitorável.
- ***Secrets* via OCI Vault, não em variáveis de ambiente comuns.**

---

### Etapa 5: API (Hono + Bun + DuckDB)

**Objetivo:** *endpoints* REST que servem (i) séries históricas de margem, (ii) decomposição por período, (iii) simulação de cenários.

**Boas práticas:**

- ***Endpoints* com semântica clara.** `/margins?from=...&to=...&granularity=daily` é melhor que `/data?q=...`.
- **Documentação OpenAPI gerada automaticamente.** Serve de contrato com o *frontend* e de documentação de TCC.
- **Cache em memória para consultas frequentes.** Margem de ontem não muda; cache de 5 min reduz pressão sobre o Object Storage.
- ***Rate limiting* mesmo num projeto pequeno.** Boa higiene desde o início.
- **DuckDB sobre Parquet remoto.** Aprenda a usar *predicate pushdown* para reduzir bytes lidos.
- **Validação de entrada com Zod (TS).** Espelha a filosofia *fail-fast* do Pydantic na ingestão.

---

### Etapa 6: Dashboard (Next.js + Tailwind)

**Objetivo:** três telas principais: margem histórica, decomposição do *crush*, simulador de cenários.

**Boas práticas:**

- ***Server Components* por padrão; *Client Components* só quando precisar de interatividade.** Reduz JS enviado ao cliente.
- **Visualizações simples e auditáveis.** Linha temporal da margem, *stacked area* da decomposição, sliders no simulador. Evite *charts* exóticos; economista lê linha e barra com fluência.
- ***Loading states* explícitos.** Dado vem da API; treine bons padrões de UX assíncrona.
- **Acessibilidade.** Cores com contraste adequado, *labels* em todos os inputs do simulador.

---

## 5. Considerações estatísticas e econométricas

A banca é de Economia. Mesmo que o produto principal seja de engenharia de dados, é **essencial** demonstrar rigor nas séries temporais.

**Tópicos a abordar na monografia:**

- **Estacionariedade.** Aplicar testes (ADF, KPSS) nas séries originais e em diferenças. Documentar a ordem de integração.
- **Cointegração.** O boi e o milho são cointegrados? Existe relação de longo prazo? Teste de Engel-Granger ou Johansen.
- **Sazonalidade.** Pecuária tem ciclos sazonais marcantes (entressafra de boi, safra de grãos). Quantificar e documentar.
- **Quebras estruturais.** Eventos como crise de 2008, pandemia de 2020, embargo da China. Marcadores no gráfico, dummies no modelo.
- **Decomposição da margem.** Atribuir variação da margem a cada componente (preço do boi vs. milho vs. juros). Usa *shift-share* ou regressão.
- **Limites do modelo.** Não modelamos custo de mão-de-obra, sanidade, mortalidade. Documente como premissas explícitas.

**Boa prática:** todo gráfico do dashboard deve ter, ao lado, a referência metodológica que sustenta aquela visualização. A banca aprecia.

---

## 6. Como apresentar para uma banca de economia

- **Comece pelo problema, não pela tecnologia.** Abra com "o pecuarista decide diariamente entre confinar mais X dias ou abater", não com "construí um *data lake* na OCI". A tecnologia é meio, o problema é fim.
- **Use analogias econômicas para conceitos técnicos.** "Medallion" = "regimes de tratamento progressivo do dado, análogo a estágios de manufatura". "Pydantic" = "controle de qualidade na entrada, análogo a inspeção em ponto de recebimento". A banca conecta.
- **Mostre uma decisão real sendo tomada.** O simulador do dashboard é a peça mais persuasiva da defesa. Permita à banca tocar nos *sliders* (Selic, preço do milho) e ver a margem mudar.
- **Seja honesto com limitações.** "Não modelamos custos não-alimentares; eles entram como parâmetro" é melhor do que esconder a simplificação.
- **Conecte com literatura.** Há trabalhos sobre *crush spread* em *commodities* agrícolas (Wisner, Irwin & Good, Hayenga). Citá-los ancora o trabalho na fronteira acadêmica.

---

## 7. Riscos e premissas

- **Disponibilidade das fontes.** CEPEA e B3 podem mudar formato. *Mitigação:* validação rigorosa no *bronze* + alertas em quebra de *schema*.
- **Custo de produção fixo.** Itens não-alimentares (mão-de-obra, sanidade, depreciação) são premissa, não variável. *Mitigação:* documentar e permitir *override* no simulador.
- **Selic como proxy do custo de capital.** É uma simplificação. Custo real do crédito ao pecuarista é maior (ex.: Pronaf, custeio agrícola). *Mitigação:* permitir trocar a taxa no simulador.
- ***Always Free* da OCI.** Há limites (storage, *compute*). *Mitigação:* *lifecycle policies* + monitoramento de uso.
- **Dados de futuros B3.** Acesso programático é restrito. *Mitigação:* uso do histórico end-of-day público, com defasagem documentada.

---

## 8. Próximas iterações (pós-TCC)

Mantém-se de fora do escopo mínimo, mas vale registrar para futura referência:

- Incorporar carcaça/desossa para calcular margem da indústria, não só da fazenda.
- Modelo de previsão da margem em 30/60/90 dias com curva de futuros + variáveis climáticas.
- Alertas (e-mail/Telegram) quando a margem cruza limiares definidos pelo usuário.
- Backtest de estratégias de *hedge* (vender futuro BGI quando margem > X).

---

## 9. Onde aprender (referências canônicas)

- **Arquitetura:** [Architecture Patterns with Python (Cosmic Python)](https://www.cosmicpython.com/book/preface.html), capítulos 1–6.
- **Hexagonal:** [Alistair Cockburn: Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/).
- **Medallion:** [Databricks Glossary: Medallion Architecture](https://www.databricks.com/glossary/medallion-architecture).
- **Delta Lake:** [Delta Lake Documentation: Concepts](https://docs.delta.io/latest/delta-intro.html).
- **Boas práticas Python:** [The Twelve-Factor App](https://12factor.net/) (especialmente seções III, X, XI).
- **Pydantic:** [docs.pydantic.dev](https://docs.pydantic.dev/latest/).
- **Crush spread (literatura aplicada):** Hayenga & DiPietre (1982), *Hedging Wholesale Meat Prices*; Wisner, *Iowa Soybean Crush Margin Outlook*; Irwin & Good (Ag Markdaily); buscar via Google Scholar.
- **Séries temporais financeiras:** Tsay, *Analysis of Financial Time Series*; Enders, *Applied Econometric Time Series*.
