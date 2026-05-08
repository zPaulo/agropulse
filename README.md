# AgroPulse

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Oracle Cloud](https://img.shields.io/badge/Oracle_Cloud-F80000?style=for-the-badge&logo=oracle&logoColor=white)
![Python](https://img.shields.io/badge/Python_3.14-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Pydantic](https://img.shields.io/badge/Pydantic-E92063?style=for-the-badge&logo=pydantic&logoColor=white)
![Databricks](https://img.shields.io/badge/Databricks-FF3621?style=for-the-badge&logo=databricks&logoColor=white)
![Delta Lake](https://img.shields.io/badge/Delta_Lake-003366?style=for-the-badge&logo=delta&logoColor=white)
![Hono](https://img.shields.io/badge/Hono-E36002?style=for-the-badge&logo=hono&logoColor=white)
![Bun](https://img.shields.io/badge/Bun-000000?style=for-the-badge&logo=bun&logoColor=white)
![DuckDB](https://img.shields.io/badge/DuckDB-FFF000?style=for-the-badge&logo=duckdb&logoColor=black)
![Next.js](https://img.shields.io/badge/Next.js_15-000000?style=for-the-badge&logo=nextdotjs&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![Tailwind](https://img.shields.io/badge/Tailwind_CSS-06B6D4?style=for-the-badge&logo=tailwindcss&logoColor=white)
![License MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

> Plataforma de inteligência de **margem para pecuária de confinamento**, baseada no *cattle crush spread*: a margem entre o preço do boi gordo e seus insumos (milho e farelo de soja), ajustada pelo custo de oportunidade do capital.

Projeto desenvolvido como **Trabalho de Conclusão de Curso** (Economia). Consiste em um pipeline de dados ponta a ponta que ingere preços oficiais à vista (CEPEA), futuros (B3) e indicadores macro (BCB), aplica arquitetura *medallion* sobre Delta Lake, calcula a margem de confinamento em tempo quase real e expõe os resultados via API e dashboard interativo.

---

## O problema

Em pecuária de corte, a decisão econômica mais crítica do ciclo de terminação não é *quanto* o boi gordo vale hoje, e sim se a margem entre **receita esperada** (boi gordo) e **custo total** (alimentação + custo de oportunidade do capital empatado) **justifica confinar mais 90 a 120 dias** ou abater agora.

Esse cálculo é análogo ao *crack spread* do refino de petróleo e ao *soybean crush* da indústria de esmagamento de soja: uma diferença entre o produto final e a soma ponderada de seus insumos. Toda *trading* de proteína e todo frigorífico de grande porte calcula essa margem internamente, em planilhas isoladas, com séries históricas curtas. Não há, em português, uma ferramenta pública que (i) cruze as fontes oficiais com rigor, (ii) preserve a auditabilidade do dado e (iii) entregue a margem em formato analisável.

O AgroPulse preenche essa lacuna.

---

## Visão geral

O pipeline cobre o ciclo completo de uma plataforma de dados aplicada a um problema econômico bem definido:

1. **Ingestão** automatizada de preços à vista (CEPEA), preços futuros (B3 BGI) e indicadores macroeconômicos (BCB).
2. **Armazenamento** em camadas (*bronze*, *silver*, *gold*) sobre OCI Object Storage, com imutabilidade do dado bruto.
3. **Processamento** distribuído com Databricks e Delta Lake, calculando a margem de confinamento em base diária.
4. **Serviço** via API REST de baixa latência consultando Parquet com DuckDB.
5. **Visualização** em dashboard responsivo com Next.js, com decomposição do crush spread e simulador de cenários.

Toda a infraestrutura é provisionada de forma reprodutível com **Terraform** na **Oracle Cloud Infrastructure (OCI)**.

---

## Arquitetura

```
┌──────────────┐     ┌────────────────────────────┐     ┌──────────────┐
│   Fontes     │     │   Camadas Medallion (OCI)  │     │   Consumo    │
│              │     │                            │     │              │
│  CEPEA       │ ──► │   bronze (raw JSON/CSV)    │     │              │
│  (boi/grãos) │     │     │                      │     │              │
│              │     │     ▼                      │     │              │
│  B3 BGI      │     │   silver (parquet limpo)   │ ──► │  API Hono    │ ──► Dashboard
│  (futuros)   │     │     │                      │     │  + DuckDB    │     Next.js
│              │     │     ▼                      │     │              │
│  BCB         │     │   gold (margem +           │     │              │
│  (Selic, FX) │     │   decomposição do crush)   │     │              │
└──────────────┘     │                            │     └──────────────┘
       ▲             └────────────────────────────┘
       │                          ▲
       │                          │
       │             ┌────────────┴────────────┐
       └─────────────│  Ingestão Python        │
                     │  (Pydantic + pytest)    │
                     └─────────────────────────┘
```

### Stack tecnológica

| Camada              | Tecnologia                          | Papel                                            |
|---------------------|-------------------------------------|--------------------------------------------------|
| Infraestrutura      | Terraform + OCI                     | Provisionamento declarativo e reprodutível       |
| Armazenamento       | OCI Object Storage                  | Data lake nas camadas bronze / silver / gold     |
| Ingestão            | Python 3.14, Pydantic, httpx        | Coleta tipada e validação *fail-fast*            |
| Processamento       | Databricks Community + Delta Lake   | ETL distribuído com versionamento de tabelas     |
| API                 | Hono + Bun + DuckDB                 | Consulta direta a Parquet com latência mínima    |
| Frontend            | Next.js 15 + Tailwind               | Dashboard de margem e simulador de cenários      |
| CI/CD               | GitHub Actions                      | `terraform plan/apply` e deploy da API           |

---

## Fontes de dados

| Fonte                                    | Variáveis                                                       | Papel no modelo                          |
|------------------------------------------|-----------------------------------------------------------------|------------------------------------------|
| **CEPEA / ESALQ-USP**                    | Indicador do boi gordo (BGI), milho e farelo de soja            | Receita e custos variáveis à vista       |
| **B3 (Bolsa Brasil Balcão)**             | Cotações de ajuste do contrato futuro de boi gordo (BGI)        | Expectativa de mercado e *hedge*         |
| **BCB / SGS**                            | Taxa Selic e câmbio USD/BRL (PTAX)                              | Custo de oportunidade do capital e paridade de exportação |

> Fontes complementares (CONAB, IBGE/SIDRA) podem ser incorporadas como variáveis de controle em iterações posteriores, mas não fazem parte do escopo mínimo do TCC.

---

## O que é o *cattle crush spread*

A margem bruta diária do confinamento, em R\$/@ de carcaça, pode ser decomposta como:

```
Margem = Receita(boi gordo) − Custo alimentar(milho, farelo de soja) − Custo de oportunidade(Selic × capital empatado × dias)
```

O *gold* do *data lake* materializa essa margem em base diária, com cada componente isolado para que a decomposição seja auditável e o efeito de cada variável (preço do boi, preço dos grãos, taxa de juros) possa ser analisado separadamente.

---

## Roadmap de execução

O projeto é entregue em etapas, cada uma se apoiando na anterior:

1. **Etapa 1, Infra base (Terraform):** VCN, Object Storage (bronze/silver/gold), IAM e remote state.
2. **Etapa 2, Ingestão (Python):** *scrapers* tipados para CEPEA, B3 e BCB, com validação Pydantic e *upload* para *bronze*.
3. **Etapa 3, Pipeline medallion (Databricks):** transformação *bronze → silver → gold* com Delta Lake; cálculo da margem e decomposição do *crush*.
4. **Etapa 4, Compute (Terraform):** provisionamento da instância que hospeda a API.
5. **Etapa 5, API (Hono + Bun):** *endpoints* servindo séries de margem e cenários via DuckDB sobre Parquet.
6. **Etapa 6, Dashboard (Next.js):** visualização da margem histórica, decomposição e simulador de confinamento; *deploy* na Vercel.

---

## Decisões de design

- **Por que margem de confinamento?** O cálculo é universal entre frigoríficos e *traders*, mas hoje vive em planilhas isoladas. Existe um *gap* claro de ferramenta pública em PT-BR e uma decisão econômica relevante atrelada (confinar × abater).
- **Por que OCI e não AWS?** O *Always Free Tier* da Oracle inclui *Compute*, *Object Storage* e rede sem prazo de expiração, viabilizando o projeto sem custo recorrente.
- **Por que medallion (bronze/silver/gold)?** Padrão consolidado em engenharia de dados que separa claramente *raw immutable*, *cleaned* e *business-ready*. Garante auditabilidade do dado bruto, requisito acadêmico essencial.
- **Por que Selic como custo de oportunidade?** Proxy padrão em finanças corporativas para o custo do capital de baixo risco no Brasil. Pode ser substituída por CDI ou IPCA+ em variantes do modelo.
- **Por que DuckDB na API?** Permite consultas SQL sub-segundo direto sobre Parquet no *Object Storage*, sem banco transacional separado, adequado a séries temporais financeiras.
- **Por que Hono + Bun?** *Framework* leve com *cold start* mínimo, adequado à instância OCI de baixa especificação.
- **Por que Pydantic na ingestão?** Garante que dados malformados das fontes públicas falhem cedo, antes de poluir o *bronze*.

---

## Documentação complementar

- [`plan.md`](plan.md): passo a passo conceitual do pipeline, com boas práticas em cada etapa.

---

## Licença

Distribuído sob a licença **MIT**. Veja [LICENSE](LICENSE) para os termos completos.

---

## Autor

**Paulo Arruda** &nbsp;·&nbsp; paulo.arruda@masterboi.com.br
