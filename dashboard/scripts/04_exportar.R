# ---------------------------------------------------------------------------
# Painel do Mercado de Trabalho (GECOMT): exportação dos dados do painel
# Lê os agregados de data-raw/ e grava arquivos leves em dashboard/data/,
# consumidos pelo painel (Observable JS) sem necessidade de R no navegador.
#
# Uso: Rscript dashboard/scripts/04_exportar.R
# ---------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(jsonlite)
  library(readr)
})

raw <- Sys.getenv("PAINEL_RAW", "dashboard/data-raw")
out <- Sys.getenv("PAINEL_OUT", "dashboard/data")
dir.create(out, showWarnings = FALSE, recursive = TRUE)

as_data <- function(aaaamm) as.Date(paste0(substr(aaaamm, 1, 4), "-", substr(aaaamm, 5, 6), "-01"))

tab_uf <- tibble::tribble(
  ~uf, ~sigla, ~nome_uf, ~regiao,
  11,"RO","Rondônia","Norte", 12,"AC","Acre","Norte", 13,"AM","Amazonas","Norte",
  14,"RR","Roraima","Norte", 15,"PA","Pará","Norte", 16,"AP","Amapá","Norte",
  17,"TO","Tocantins","Norte", 21,"MA","Maranhão","Nordeste", 22,"PI","Piauí","Nordeste",
  23,"CE","Ceará","Nordeste", 24,"RN","Rio Grande do Norte","Nordeste",
  25,"PB","Paraíba","Nordeste", 26,"PE","Pernambuco","Nordeste", 27,"AL","Alagoas","Nordeste",
  28,"SE","Sergipe","Nordeste", 29,"BA","Bahia","Nordeste", 31,"MG","Minas Gerais","Sudeste",
  32,"ES","Espírito Santo","Sudeste", 33,"RJ","Rio de Janeiro","Sudeste",
  35,"SP","São Paulo","Sudeste", 41,"PR","Paraná","Sul", 42,"SC","Santa Catarina","Sul",
  43,"RS","Rio Grande do Sul","Sul", 50,"MS","Mato Grosso do Sul","Centro-Oeste",
  51,"MT","Mato Grosso","Centro-Oeste", 52,"GO","Goiás","Centro-Oeste",
  53,"DF","Distrito Federal","Centro-Oeste")
write_csv(tab_uf, file.path(out, "ufs.csv"))

# ---- PNAD Contínua --------------------------------------------------------
p <- file.path(raw, "pnadc")
if (dir.exists(p)) {
  ind <- read_parquet(file.path(p, "indicadores.parquet")) |>
    transmute(data = as_data(periodo), indicador, nome, unidade, valor) |> filter(!is.na(valor))
  pos <- read_parquet(file.path(p, "posicao.parquet")) |>
    transmute(data = as_data(periodo), categoria, valor) |> filter(!is.na(valor))
  ati <- read_parquet(file.path(p, "atividade.parquet")) |>
    transmute(data = as_data(periodo), categoria, valor) |> filter(!is.na(valor))
  write_csv(ind, file.path(out, "pnadc_indicadores.csv"))
  write_csv(pos, file.path(out, "pnadc_posicao.csv"))
  write_csv(ati, file.path(out, "pnadc_atividade.csv"))
}

# ---- Novo CAGED -------------------------------------------------------------
cg <- file.path(raw, "caged")
fg <- list.files(cg, "^geral_\\d{4}(_\\d+)?\\.parquet$", full.names = TRUE)
if (length(fg)) {
  geral <- bind_rows(lapply(fg, read_parquet)) |>
    filter(uf %in% tab_uf$uf, !is.na(secao), secao != "Z", comp >= 202001) |>
    group_by(comp, uf, secao) |>
    summarise(across(c(admissoes, desligamentos, saldo, soma_sal_adm, n_sal_adm), ~ sum(.x, na.rm = TRUE)),
              .groups = "drop") |>
    mutate(data = as_data(comp), sal_soma = round(soma_sal_adm), .keep = "unused") |>
    select(data, uf, secao, admissoes, desligamentos, saldo, sal_soma, sal_n = n_sal_adm) |>
    arrange(data, uf, secao)
  write_csv(geral, file.path(out, "caged_uf_secao.csv"))

  fc <- list.files(cg, "^contabil_\\d{4}(_\\d+)?\\.parquet$", full.names = TRUE)
  contabil <- bind_rows(lapply(fc, read_parquet)) |>
    filter(uf %in% tab_uf$uf, comp >= 202001) |>
    group_by(comp, uf, cbo, setor, sexo) |>
    summarise(across(c(admissoes, desligamentos, saldo, soma_sal_adm, n_sal_adm), ~ sum(.x, na.rm = TRUE)),
              .groups = "drop") |>
    mutate(data = as_data(comp), sal_soma = round(soma_sal_adm), .keep = "unused") |>
    select(data, uf, cbo, setor, sexo, admissoes, desligamentos, saldo,
           sal_soma, sal_n = n_sal_adm) |>
    arrange(data, uf, cbo)
  write_csv(contabil, file.path(out, "caged_contabil.csv"))
}

# ---- RAIS ---------------------------------------------------------------
rs <- file.path(raw, "rais")
if (file.exists(file.path(rs, "contabil.parquet"))) {
  write_csv(read_parquet(file.path(rs, "contabil.parquet")), file.path(out, "rais_contabil.csv"))
  write_csv(read_parquet(file.path(rs, "geral.parquet")),    file.path(out, "rais_geral.csv"))
}

# ---- Metadados ---------------------------------------------------------------
meta <- list(atualizado_em = format(Sys.Date()))
if (exists("ind"))      meta$pnadc_ultimo <- format(max(ind$data))
if (exists("geral"))    meta$caged_ultimo <- format(max(geral$data))
if (file.exists(file.path(rs, "ano.txt"))) meta$rais_ano <- readLines(file.path(rs, "ano.txt"))
write_json(meta, file.path(out, "meta.json"), auto_unbox = TRUE, pretty = TRUE)
message("Exportação concluída: ", paste(list.files(out), collapse = ", "))
