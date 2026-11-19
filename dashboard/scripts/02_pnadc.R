# ---------------------------------------------------------------------------
# Painel do Mercado de Trabalho (GECOMT): indicadores da PNAD Contínua
# Fonte: IBGE, Sistema IBGE de Recuperação Automática (SIDRA), trimestres móveis
#
# Uso: Rscript dashboard/scripts/02_pnadc.R
# ---------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
  library(arrow)
})

dir_out <- Sys.getenv("PNADC_OUT", "dashboard/data-raw/pnadc")
dir.create(dir_out, showWarnings = FALSE, recursive = TRUE)

sidra <- function(caminho) {
  url <- paste0("https://apisidra.ibge.gov.br/values", caminho, "?formato=json")
  x <- fromJSON(url)[-1, ]  # a primeira linha traz os rótulos
  tibble(
    periodo   = x$D3C,                      # AAAAMM (último mês do trimestre móvel)
    categoria = if ("D4N" %in% names(x)) x$D4N else NA_character_,
    valor     = suppressWarnings(as.numeric(x$V))
  )
}

ind <- list(
  list(id = "pia",          nome = "População em idade de trabalhar (14+)", un = "mil pessoas",
       q = "/t/6318/n1/all/v/1641/p/all/c629/32385"),
  list(id = "forca",        nome = "Força de trabalho",            un = "mil pessoas",
       q = "/t/6318/n1/all/v/1641/p/all/c629/32386"),
  list(id = "ocupados",     nome = "Ocupados",                     un = "mil pessoas",
       q = "/t/6318/n1/all/v/1641/p/all/c629/32387"),
  list(id = "desocupados",  nome = "Desocupados",                  un = "mil pessoas",
       q = "/t/6318/n1/all/v/1641/p/all/c629/32446"),
  list(id = "fora",         nome = "Fora da força de trabalho",    un = "mil pessoas",
       q = "/t/6318/n1/all/v/1641/p/all/c629/32447"),
  list(id = "tx_desocup",   nome = "Taxa de desocupação",          un = "%",
       q = "/t/6381/n1/all/v/4099/p/all"),
  list(id = "nivel_ocup",   nome = "Nível da ocupação",            un = "%",
       q = "/t/6379/n1/all/v/4097/p/all"),
  list(id = "rend_medio",   nome = "Rendimento médio real habitual", un = "R$",
       q = "/t/6390/n1/all/v/5933/p/all"),
  list(id = "massa_rend",   nome = "Massa de rendimento real habitual", un = "R$ milhões",
       q = "/t/6392/n1/all/v/6293/p/all")
)

serie <- bind_rows(lapply(ind, function(i) {
  message("SIDRA: ", i$nome)
  sidra(i$q) |> mutate(indicador = i$id, nome = i$nome, unidade = i$un) |> select(-categoria)
}))

# Taxa de participação em trimestres móveis: força de trabalho / população de 14 anos ou mais
# (a tabela 6461 do SIDRA é trimestral, não móvel, por isso o cálculo a partir da tabela 6318)
partic <- serie |>
  filter(indicador %in% c("forca", "pia")) |>
  select(periodo, indicador, valor) |>
  tidyr::pivot_wider(names_from = indicador, values_from = valor) |>
  transmute(periodo, valor = round(100 * forca / pia, 1),
            indicador = "tx_partic", nome = "Taxa de participação", unidade = "%")
serie <- bind_rows(serie, partic)

posicao <- sidra("/t/6320/n1/all/v/4090/p/all/c11913/31722,31723,31724,31727,96170,96171,31731") |>
  mutate(categoria = recode(categoria,
    "Empregado no setor privado, exclusive trabalhador doméstico - com carteira de trabalho assinada" = "Empregado com carteira",
    "Empregado no setor privado, exclusive trabalhador doméstico - sem carteira de trabalho assinada" = "Empregado sem carteira"))

atividade <- sidra("/t/6323/n1/all/v/4090/p/all/c888/allxt")

write_parquet(serie,     file.path(dir_out, "indicadores.parquet"))
write_parquet(posicao,   file.path(dir_out, "posicao.parquet"))
write_parquet(atividade, file.path(dir_out, "atividade.parquet"))
message("Último trimestre móvel: ", max(serie$periodo))
