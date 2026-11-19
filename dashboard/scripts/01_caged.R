# ---------------------------------------------------------------------------
# Painel do Mercado de Trabalho (GECOMT): agregados do Novo CAGED
# Fonte: microdados do Novo CAGED via pacote datacaged (gecomt/datacaged)
#
# O script processa um ano por vez (download, carga em DuckDB temporário,
# agregação e descarte), o que mantém o uso de disco baixo. O saldo segue a
# lógica das estatísticas oficiais: movimentações declaradas no prazo (MOV)
# + declarações fora do prazo (FOR) - exclusões (EXC), por competência.
#
# Uso: Rscript dashboard/scripts/01_caged.R [ano_inicial] [ano_final]
# ---------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(datacaged)
  library(DBI)
  library(arrow)
})

args   <- commandArgs(trailingOnly = TRUE)
ano_i  <- if (length(args) >= 1) as.integer(args[1]) else 2020L
ano_f  <- if (length(args) >= 2) as.integer(args[2]) else as.integer(format(Sys.Date(), "%Y"))
dir_tmp <- Sys.getenv("CAGED_TMP", "dados-tmp")
dir_out <- Sys.getenv("CAGED_OUT", "dashboard/data-raw/caged")
dir.create(dir_tmp, showWarnings = FALSE, recursive = TRUE)
dir.create(dir_out, showWarnings = FALSE, recursive = TRUE)

disponiveis <- caged_hf_files()

base_sql <- "
WITH base AS (
  SELECT competenciamov AS comp, uf, secao, CAST(cbo2002ocupacao AS VARCHAR) AS cbo,
         sexo, racacor, salario, horascontratuais, saldomovimentacao AS s, 1 AS w
  FROM caged_mov
  UNION ALL
  SELECT competenciamov, uf, secao, CAST(cbo2002ocupacao AS VARCHAR),
         sexo, racacor, salario, horascontratuais, saldomovimentacao, 1
  FROM caged_for
  UNION ALL
  SELECT competenciamov, uf, secao, CAST(cbo2002ocupacao AS VARCHAR),
         sexo, racacor, salario, horascontratuais, saldomovimentacao, -1
  FROM caged_exc
),
b AS (
  SELECT *,
    CASE WHEN w = 1 AND s = 1 AND horascontratuais > 0
              AND salario BETWEEN 300 AND 100000 THEN salario END AS sal_adm
  FROM base
)
"

sql_geral <- paste0(base_sql, "
SELECT comp, uf, secao,
       SUM(w * (s = 1)::INT)  AS admissoes,
       SUM(w * (s = -1)::INT) AS desligamentos,
       SUM(w * s)             AS saldo,
       SUM(sal_adm)           AS soma_sal_adm,
       COUNT(sal_adm)         AS n_sal_adm
FROM b GROUP BY ALL")

sql_contabil <- paste0(base_sql, "
SELECT comp, uf,
       CASE WHEN substr(cbo, 1, 4) = '2522' THEN 'Contadores e auditores'
            ELSE 'Técnicos em contabilidade' END AS grupo,
       sexo, racacor,
       SUM(w * (s = 1)::INT)  AS admissoes,
       SUM(w * (s = -1)::INT) AS desligamentos,
       SUM(w * s)             AS saldo,
       SUM(sal_adm)           AS soma_sal_adm,
       COUNT(sal_adm)         AS n_sal_adm
FROM b WHERE substr(cbo, 1, 4) IN ('2522', '3511')
GROUP BY ALL")

for (ano in ano_i:ano_f) {
  meses <- disponiveis$mes[disponiveis$ano == ano]
  if (ano < max(disponiveis$ano)) meses <- 1:12  # anos fechados (lista do HF traz só os últimos)
  if (length(meses) == 0) next
  db <- file.path(dir_tmp, sprintf("caged_%d.duckdb", ano))
  message(sprintf("[%s] Ano %d: meses %s", format(Sys.time(), "%H:%M"), ano, paste(range(meses), collapse = "-")))
  dir_dl <- file.path(dir_tmp, "downloads")
  caged_load(years = ano, months = sort(as.integer(meses)), db_path = db,
             destdir = dir_dl, workers = as.integer(Sys.getenv("CAGED_WORKERS", "1")))
  con <- dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  # limita a memória da agregação (evita estouro em máquinas com pouca RAM)
  dbExecute(con, sprintf("SET memory_limit = '%s'", Sys.getenv("CAGED_MEM", "3GB")))
  dbExecute(con, "SET preserve_insertion_order = false")
  dbExecute(con, sprintf("SET temp_directory = '%s'", file.path(dir_tmp, "duckdb_tmp")))
  write_parquet(dbGetQuery(con, sql_geral),    file.path(dir_out, sprintf("geral_%d.parquet", ano)))
  write_parquet(dbGetQuery(con, sql_contabil), file.path(dir_out, sprintf("contabil_%d.parquet", ano)))
  dbDisconnect(con, shutdown = TRUE)
  unlink(db)
  unlink(dir_dl, recursive = TRUE)
}
message("Concluído.")
