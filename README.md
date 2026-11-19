# Blog do GECOMT

Site e blog do **Grupo de Estudos sobre Contabilidade e Mercado de Trabalho (GECOMT/UFERSA)**,
feito em [Quarto](https://quarto.org) a partir da estrutura do repositório
[quarto-web](https://github.com/quarto-dev/quarto-web).

## Estrutura

```
_quarto.yml                 configuração do site (menu, rodapé, URL)
_extensions/gecomt/         tipo de projeto "gecomt" (tema, formato e opções, como o quartoorg)
  scss/gecomt.scss          tema claro (paleta da marca)
  scss/gecomt-dark.scss     tema escuro
  scss/partials/            regras de navbar, página inicial, listagens, rodapé
assets/images/              favicon, imagem de compartilhamento e emblemas recortados
assets/images/logos/        todos os arquivos de logo originais
index.qmd                   página inicial
dashboard/                  Painel do Mercado de Trabalho (dados e scripts em R)
pacotes/datacaged.qmd       página dedicada ao dataCAGED
pacotes/datarais.qmd        página dedicada ao dataRAIS
assets/images/pacotes/      logos hexagonais dos pacotes
sobre.qmd, equipe.qmd, producao.qmd
equipe/membros.yml          lista de membros (cada item vira um cartão)
blog/index.qmd              listagem do blog (categorias, filtro, RSS)
blog/posts/AAAA-MM-DD-slug/ um post por pasta (index.qmd + thumbnail.png)
_modelos/novo-post.qmd      modelo para novos posts
```

## Paleta

| Cor | Hex | Uso |
|---|---|---|
| Azul institucional | `#133355` | navbar, banners, títulos |
| Azul claro | `#1B4472` | gradientes, links |
| Azul escuro | `#0F2A48` | rodapé, gradientes |
| Dourado | `#F3C043` | destaques sobre fundo escuro, botões |
| Dourado (fundo claro) | `#E0A82E` | detalhes sobre fundo branco |
| Cinza | `#5A6470` / `#BDC3C8` | textos secundários |

Tipografia: Poppins (títulos) e Inter (texto), via Google Fonts.

## Uso

```bash
quarto preview      # pré-visualização local
quarto render       # gera o site em docs/
```

### Novo post

1. Crie a pasta `blog/posts/AAAA-MM-DD-slug/`;
2. Copie `_modelos/novo-post.qmd` para `index.qmd` dentro dela e edite;
3. Inclua uma `thumbnail.png` (1200 x 675 px).

Posts com código R ou Python executável usam `freeze`, de modo que o resultado
fica salvo em `_freeze/` e não é recalculado na publicação.

### Posts de um pacote

Inclua a categoria `dataCAGED` ou `dataRAIS` no post para que ele apareça
automaticamente na seção "Posts sobre..." da página do pacote.

### Novo membro

Edite `equipe/membros.yml` e coloque a foto quadrada em `equipe/`.

## Painel do Mercado de Trabalho

O painel (`dashboard/index.qmd`) substitui a antiga versão em shinyapps.io e é gerado como página
estática (Quarto Dashboard + Observable JS), sem necessidade de servidor. Os dados ficam em
`dashboard/data/` e são produzidos pelos scripts de `dashboard/scripts/`:

| Script | Fonte | Saída |
|---|---|---|
| `01_caged.R` | Novo CAGED (pacote `datacaged`) | agregados por competência, UF e seção CNAE; recorte CBO 2522/3511 |
| `02_pnadc.R` | PNAD Contínua (API SIDRA/IBGE) | indicadores em trimestres móveis |
| `03_rais.R` | RAIS (pacote `datarais`) | vínculos ativos e remuneração dos profissionais contábeis |
| `04_exportar.R` | agregados acima | CSV/JSON leves em `dashboard/data/` |

Atualização mensal (na raiz do repositório):

```bash
Rscript dashboard/scripts/01_caged.R 2026 2026   # reprocessa o ano corrente do CAGED
Rscript dashboard/scripts/02_pnadc.R
Rscript dashboard/scripts/03_rais.R              # apenas quando sair nova RAIS
Rscript dashboard/scripts/04_exportar.R
quarto render
```

O CAGED é processado um ano por vez (DuckDB temporário), o que mantém o uso de disco baixo.
Como as declarações fora do prazo de um ano chegam nos arquivos do ano seguinte, ao reprocessar
o ano corrente convém reprocessar também o anterior. Os agregados intermediários ficam em
`dashboard/data-raw/` (fora do controle de versão).

## Publicação no GitHub Pages

O site é publicado a partir da pasta `docs/` da branch `main` do repositório
`gecomt/gecomt.github.io` (*Settings > Pages > Deploy from a branch > main /docs*).

```bash
quarto render
git add -A
git commit -m "Atualiza site"
git push
```

Os posts antigos (2024) foram migrados e mantêm os endereços originais por meio de
redirecionamentos (`aliases`).
