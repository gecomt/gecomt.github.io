# ---------------------------------------------------------------------------
# Painel do Mercado de Trabalho (GECOMT): agregados da RAIS
# Fonte: microdados de vínculos da RAIS. Download via pacote datarais
# (gecomt/datarais); leitura direta com DuckDB, compatível com o leiaute
# antigo (.txt, separador ";") e com o leiaute .COMT adotado pelo MTE a
# partir da RAIS 2024 (separador ",", colunas "<variável> - Código").
#
# Recorte: vínculos ativos em 31/12 em oito ocupações contábeis da CBO 2002
# (252205, 252210, 252215, 234815, 351105, 351110, 351115 e 413110); setor
# público = natureza jurídica do grupo 1 (administração pública); remuneração
# nominal de dezembro.
#
# Uso: Rscript dashboard/scripts/03_rais.R [ano]   (padrão: ano mais recente)
# ---------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(datarais)
  library(DBI)
  library(arrow)
})

args    <- commandArgs(trailingOnly = TRUE)
ano     <- if (length(args) >= 1) as.integer(args[1]) else max(rais_available()$ano)
dir_tmp <- Sys.getenv("RAIS_TMP", "dados-tmp")
dir_out <- Sys.getenv("RAIS_OUT", "dashboard/data-raw/rais")
dir_dl  <- file.path(dir_tmp, "downloads_rais")
dir_ext <- file.path(dir_tmp, "rais_extraido")
dir.create(dir_out, showWarnings = FALSE, recursive = TRUE)
dir.create(dir_ext, showWarnings = FALSE, recursive = TRUE)

# 1) Download (cache local do datarais) --------------------------------------
message("RAIS ", ano, ": download")
rais_download(years = ano, destdir = dir_dl)
arquivos <- list.files(dir_dl, pattern = "VINC.*\\.7z$", recursive = TRUE,
                       full.names = TRUE, ignore.case = TRUE)
arquivos <- arquivos[grepl(sprintf("/%d/", ano), arquivos) & !grepl("Parcial|Legado", arquivos)]
if (!length(arquivos)) stop("Nenhum arquivo de vínculos encontrado para ", ano)

# 2) Leitura e agregação por arquivo ------------------------------------------
con <- dbConnect(duckdb::duckdb())
dbExecute(con, sprintf("SET memory_limit = '%s'", Sys.getenv("RAIS_MEM", "3GB")))
dbExecute(con, "SET preserve_insertion_order = false")
dbExecute(con, sprintf("SET temp_directory = '%s'", file.path(dir_tmp, "duckdb_tmp")))

cbo_contabil <- c("252205", "252210", "252215", "234815", "351105", "351110", "351115", "413110")

coluna <- function(nomes, padrao) {
  i <- grep(padrao, nomes, ignore.case = TRUE, perl = TRUE)
  if (!length(i)) stop("Coluna não encontrada: ", padrao)
  sprintf("c%d", i[1])
}

contabil <- list(); geral <- list()
for (arq in arquivos) {
  message("  ", basename(arq))
  archive::archive_extract(arq, dir = dir_ext)
  txt <- list.files(dir_ext, full.names = TRUE)[1]

  cab   <- iconv(readLines(txt, n = 1, warn = FALSE), "latin1", "UTF-8")
  delim <- if (grepl(";", cab)) ";" else ","
  nomes <- gsub('^"|"$', "", strsplit(cab, delim, fixed = TRUE)[[1]])
  num   <- if (delim == ";") function(x) sprintf("TRY_CAST(replace(%s, ',', '.') AS DOUBLE)", x)
           else function(x) sprintf("TRY_CAST(%s AS DOUBLE)", x)

  c_cbo   <- coluna(nomes, "^CBO.*2002")
  c_ativo <- coluna(nomes, "V.nculo Ativo 31/12")
  c_sexo  <- coluna(nomes, "^Sexo")
  c_raca  <- coluna(nomes, "^Ra.a Cor")
  c_esc   <- coluna(nomes, "^Escolaridade Ap.s 2005")
  c_idade <- coluna(nomes, "^Idade$")
  c_rem   <- coluna(nomes, "^Vl Rem(un)? Dezembro Nom")
  c_mun   <- coluna(nomes, "^Munic.pio( - C.digo)?$")
  c_nat   <- coluna(nomes, "^Natureza Jur.dica( - C.digo)?$")

  fonte <- sprintf(
    "read_csv('%s', header = false, skip = 1, delim = '%s', quote = '\"', all_varchar = true,
              names = [%s], null_padding = true, ignore_errors = true)",
    txt, delim, paste0("'c", seq_along(nomes), "'", collapse = ", "))

  base <- sprintf("
    SELECT TRY_CAST(substr(trim(%s), 1, 2) AS INTEGER) AS uf,
           CAST(TRY_CAST(trim(%s) AS BIGINT) AS VARCHAR) AS cbo,
           substr(trim(%s), 1, 1) AS nat,
           TRY_CAST(trim(%s) AS INTEGER) AS ativo,
           TRY_CAST(trim(%s) AS INTEGER) AS sexo,
           TRY_CAST(trim(%s) AS INTEGER) AS raca_cor,
           TRY_CAST(trim(%s) AS INTEGER) AS grau_instrucao,
           TRY_CAST(trim(%s) AS INTEGER) AS idade,
           %s AS rem
    FROM %s",
    c_mun, c_cbo, c_nat, c_ativo, c_sexo, c_raca, c_esc, c_idade, num(sprintf("trim(%s)", c_rem)), fonte)

  # Códigos dos microdados da RAIS: sexo 1 = masculino, 2 = feminino;
  # raça/cor 1 = indígena, 2 = branca, 4 = preta, 6 = amarela, 8 = parda, 9 = não identificada
  contabil[[arq]] <- dbGetQuery(con, sprintf("
    SELECT %d AS ano, uf, cbo,
           CASE WHEN nat = '1' THEN 'Público' ELSE 'Privado' END AS setor,
           CASE sexo WHEN 1 THEN 'Homens' WHEN 2 THEN 'Mulheres' ELSE 'Não informado' END AS sexo,
           CASE raca_cor WHEN 2 THEN 'Branca' WHEN 8 THEN 'Parda' WHEN 4 THEN 'Preta'
                         WHEN 1 THEN 'Outras' WHEN 6 THEN 'Outras' ELSE 'Não informada' END AS raca,
           CASE WHEN grau_instrucao <= 7 THEN 'Até médio completo'
                WHEN grau_instrucao = 8 THEN 'Superior incompleto'
                WHEN grau_instrucao = 9 THEN 'Superior completo'
                WHEN grau_instrucao >= 10 THEN 'Pós-graduação' END AS escolaridade,
           CASE WHEN idade < 25 THEN 'Até 24 anos' WHEN idade < 35 THEN '25 a 34 anos'
                WHEN idade < 45 THEN '35 a 44 anos' WHEN idade < 55 THEN '45 a 54 anos'
                ELSE '55 anos ou mais' END AS faixa_etaria,
           COUNT(*) AS vinculos,
           SUM(CASE WHEN rem > 0 THEN rem END) AS rem_soma,
           COUNT(CASE WHEN rem > 0 THEN 1 END) AS rem_n
    FROM (%s) WHERE ativo = 1 AND cbo IN (%s)
    GROUP BY ALL", ano, base, paste0("'", cbo_contabil, "'", collapse = ", ")))

  geral[[arq]] <- dbGetQuery(con, sprintf("
    SELECT %d AS ano, uf,
           CASE sexo WHEN 1 THEN 'Homens' WHEN 2 THEN 'Mulheres' ELSE 'Não informado' END AS sexo,
           COUNT(*) AS vinculos
    FROM (%s) WHERE ativo = 1 GROUP BY ALL", ano, base))

  unlink(list.files(dir_ext, full.names = TRUE))
}
dbDisconnect(con, shutdown = TRUE)

# 3) Consolidação e gravação ---------------------------------------------------
consolida <- function(lista, chaves, medidas) {
  dplyr::bind_rows(lista) |>
    dplyr::mutate(dplyr::across(dplyr::any_of(c("escolaridade")), ~ dplyr::coalesce(.x, "Não informada"))) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(chaves))) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(medidas), ~ sum(.x, na.rm = TRUE)), .groups = "drop") |>
    as.data.frame()
}
contabil <- consolida(contabil, c("ano", "uf", "cbo", "setor", "sexo", "raca", "escolaridade", "faixa_etaria"),
                      c("vinculos", "rem_soma", "rem_n"))
contabil$rem_soma <- round(contabil$rem_soma)
geral <- consolida(geral, c("ano", "uf", "sexo"), "vinculos")

write_parquet(contabil, file.path(dir_out, "contabil.parquet"))
write_parquet(geral,    file.path(dir_out, "geral.parquet"))
writeLines(as.character(ano), file.path(dir_out, "ano.txt"))
if (Sys.getenv("RAIS_MANTER_DOWNLOADS") != "1") unlink(dir_dl, recursive = TRUE)
unlink(dir_ext, recursive = TRUE)
message(sprintf("Concluído: %s vínculos ativos no total; %s no recorte contábil.",
                format(sum(geral$vinculos), big.mark = "."), format(sum(contabil$vinculos), big.mark = ".")))
