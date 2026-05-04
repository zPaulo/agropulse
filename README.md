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

> Plataforma de inteligência de mercado para o agronegócio brasileiro, com foco em pecuária de corte e commodities agrícolas.

Projeto desenvolvido como **Trabalho de Conclusão de Curso**. Consiste em um pipeline de dados ponta a ponta que ingere preços e indicadores oficiais (CEPEA, CONAB, IBGE), aplica arquitetura *medallion* sobre Delta Lake e expõe os dados refinados via API e dashboard interativo.

---

## Visão geral

O AgroPulse cobre o ciclo completo de uma plataforma de dados:

1. **Ingestão** automatizada de fontes públicas oficiais.
2. **Armazenamento** em camadas (*bronze*, *silver*, *gold*) sobre OCI Object Storage.
3. **Processamento** distribuído com Databricks e Delta Lake.
4. **Serviço** via API REST de baixa latência consultando Parquet com DuckDB.
5. **Visualização** em dashboard responsivo com Next.js.

Toda a infraestrutura é provisionada de forma reprodutível com **Terraform** na **Oracle Cloud Infrastructure (OCI)**.

---

## Arquitetura

```
┌──────────────┐     ┌────────────────────────────┐     ┌──────────────┐
│   Fontes     │     │   Camadas Medallion (OCI)  │     │   Consumo    │
│              │     │                            │     │              │
│  CEPEA       │ ──► │   bronze (raw JSON/CSV)    │     │              │
│  CONAB       │     │     │                      │     │              │
│  IBGE        │     │     ▼                      │     │              │
│              │     │   silver (parquet limpo)   │ ──► │  API Hono    │ ──► Dashboard
└──────────────┘     │     │                      │     │  + DuckDB    │     Next.js
       ▲             │     ▼                      │     │              │
       │             │   gold (agregados)         │     │              │
       │             │                            │     │              │
       │             └────────────────────────────┘     └──────────────┘
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
| Ingestão            | Python 3.12, Pydantic, requests     | Coleta e validação de dados públicos             |
| Processamento       | Databricks Community + Delta Lake   | ETL distribuído com versionamento de tabelas     |
| API                 | Hono + Bun + DuckDB                 | Consulta direta a Parquet com latência mínima    |
| Frontend            | Next.js 15 + Tailwind               | Dashboard de preços e produção                   |
| CI/CD               | GitHub Actions                      | `terraform plan/apply` e deploy da API           |

---

## Fontes de dados

| Fonte                                   | Descrição                                                    | Formato     |
|-----------------------------------------|--------------------------------------------------------------|-------------|
| **CEPEA/ESALQ-USP**                     | Indicadores diários de preços (boi gordo, soja, milho, café) | CSV / XLS   |
| **CONAB**                               | Safras, estoques e custos de produção                        | CSV         |
| **IBGE (PPM, PAM, SIDRA)**              | Pesquisa pecuária, agrícola e censo agropecuário             | API JSON    |

---

## Roadmap de execução

O projeto é entregue em etapas, com cada uma se apoiando na anterior:

1. **Etapa 1, Infra base (Terraform):** VCN, Object Storage (bronze/silver/gold), IAM e remote state.
2. **Etapa 2, Ingestão (Python):** scrapers tipados, validação Pydantic, upload para *bronze*.
3. **Etapa 3, Pipeline medallion (Databricks):** transformação *bronze → silver → gold* com Delta Lake.
4. **Etapa 4, Compute (Terraform):** provisionamento da instância que hospeda a API.
5. **Etapa 5, API (Hono + Bun):** endpoints servindo dados *gold* via DuckDB sobre Parquet.
6. **Etapa 6, Dashboard (Next.js):** visualização interativa, deployada na Vercel.

---

## Decisões de design

- **Por que OCI e não AWS?** O *Always Free Tier* da Oracle inclui Compute, Object Storage e rede sem prazo de expiração, o que viabiliza o projeto sem custo recorrente.
- **Por que medallion (bronze/silver/gold)?** É um padrão consolidado em engenharia de dados que separa claramente *raw immutable*, *cleaned* e *business-ready*.
- **Por que DuckDB na API?** Permite consultas SQL sub-segundo direto sobre Parquet no Object Storage, sem precisar de um banco transacional separado.
- **Por que Hono + Bun?** Framework leve com *cold start* mínimo, adequado a uma instância OCI de baixa especificação.
- **Por que Pydantic na ingestão?** Garante que dados malformados das fontes públicas falhem cedo, antes de poluir o *bronze*.

---

## Licença

Distribuído sob a licença **MIT**. Veja [LICENSE](LICENSE) para os termos completos.

---

## Autor

**Paulo Arruda** &nbsp;·&nbsp; paulo.arruda@masterboi.com.br
