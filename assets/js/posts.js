/* GECOMT: recursos ao final dos posts do blog (adaptado do site do ContabiliDados)
   - "Como citar" em ABNT (NBR 6023:2018) e BibTeX, com botão de copiar
   - "Compartilhe": WhatsApp, LinkedIn, X, e-mail e copiar link
   Os dados da citação vêm das metatags citation_* geradas pelo Quarto
   (google-scholar: true em blog/posts/_metadata.yml). */
(function () {
  "use strict";
  var caminho = location.pathname;
  if (!/\/blog\/posts\/[^/]+\/(index\.html)?$/.test(caminho)) return;
  var main = document.getElementById("quarto-document-content");
  if (!main) return;

  var SITE = "Blog do GECOMT";
  var CIDADE = "Mossoró";
  var ENTIDADE = "GRUPO DE ESTUDOS SOBRE CONTABILIDADE E MERCADO DE TRABALHO";
  var MESES = ["jan.", "fev.", "mar.", "abr.", "maio", "jun.", "jul.", "ago.", "set.", "out.", "nov.", "dez."];
  var SUFIXOS = ["filho", "filha", "júnior", "junior", "jr.", "neto", "neta", "sobrinho", "sobrinha"];

  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  }
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }
  function meta(nome) {
    return Array.prototype.map.call(document.querySelectorAll('meta[name="' + nome + '"]'),
      function (m) { return (m.getAttribute("content") || "").trim(); }).filter(Boolean);
  }
  function dataBR(d) { return d.getDate() + " " + MESES[d.getMonth()] + " " + d.getFullYear(); }
  function copiar(texto, botao) {
    var ok = function () {
      var orig = botao.innerHTML;
      botao.innerHTML = '<i class="bi bi-check2" aria-hidden="true"></i> Copiado';
      setTimeout(function () { botao.innerHTML = orig; }, 1800);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(texto).then(ok, function () { prompt("Copie:", texto); });
    } else { prompt("Copie:", texto); }
  }
  function antesDoTopo(no) {
    var apendice = document.getElementById("quarto-appendix");
    if (apendice && apendice.parentNode) { apendice.parentNode.insertBefore(no, apendice); return; }
    var topo = document.getElementById("quarto-back-to-top");
    if (topo && topo.parentNode === main) main.insertBefore(no, topo); else main.appendChild(no);
  }

  /* ---------- dados do post ---------- */
  var url = meta("citation_fulltext_html_url")[0] || (location.origin + caminho.replace(/index\.html$/, ""));
  var titulo = (meta("citation_title")[0] || (document.querySelector("h1.title") || {}).textContent || document.title).trim();
  var autores = meta("citation_author");
  if (!autores.length) {
    var p = document.querySelector(".quarto-title-meta-contents p:not(.date)");
    if (p) autores = p.textContent.split(/,| e /).map(function (s) { return s.trim(); }).filter(Boolean);
  }
  var dataPub = (meta("citation_publication_date")[0] || meta("citation_online_date")[0] || "").replace(/\//g, "-");
  var data = /^\d{4}-\d{2}-\d{2}/.test(dataPub) ? new Date(dataPub.slice(0, 10) + "T12:00:00") : null;
  var hoje = new Date();

  function ehEntidade(nome) { return /gecomt|equipe|grupo de estudos/i.test(nome); }
  // Autor pessoal no padrão ABNT: SOBRENOME, Prenomes (com Filho, Júnior, Neto etc.)
  function abnt(nome) {
    if (ehEntidade(nome)) return ENTIDADE;
    var partes = nome.trim().split(/\s+/);
    if (partes.length < 2) return nome.toUpperCase();
    var sob = partes.pop();
    if (SUFIXOS.indexOf(sob.toLowerCase()) >= 0 && partes.length > 1) sob = partes.pop() + " " + sob;
    return sob.toUpperCase() + ", " + partes.join(" ");
  }
  function bibNome(nome) {
    if (ehEntidade(nome)) return "{Grupo de Estudos sobre Contabilidade e Mercado de Trabalho}";
    var partes = nome.trim().split(/\s+/);
    if (partes.length < 2) return nome;
    var sob = partes.pop();
    if (SUFIXOS.indexOf(sob.toLowerCase()) >= 0 && partes.length > 1) sob = partes.pop() + " " + sob;
    return sob + ", " + partes.join(" ");
  }

  /* ---------- Como citar ---------- */
  var aut = autores.length > 3 ? abnt(autores[0]) + " et al." : autores.map(abnt).join("; ");
  var ref = (aut ? esc(aut) + ". " : "") + esc(titulo) + ". <strong>" + SITE + "</strong>, " + CIDADE +
    (data ? ", " + dataBR(data) : "") + ". Disponível em: " + esc(url) + ". Acesso em: " + dataBR(hoje) + ".";
  var refTxt = ref.replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">");
  var primeiro = autores[0] && !ehEntidade(autores[0]) ? autores[0].split(/\s+/).pop() : "gecomt";
  var chave = primeiro.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z]/g, "") +
    (data ? data.getFullYear() : "");
  var bib = "@online{" + chave + ",\n" +
    "  author       = {" + autores.map(bibNome).join(" and ") + "},\n" +
    "  title        = {" + titulo + "},\n" +
    "  organization = {" + SITE + "},\n" +
    (data ? "  date         = {" + dataPub.slice(0, 10) + "},\n" : "") +
    "  url          = {" + url + "},\n" +
    "  urldate      = {" + hoje.toISOString().slice(0, 10) + "},\n" +
    "  langid       = {portuguese}\n}";

  var citar = el("section", "nv-extra nv-citar");
  citar.innerHTML =
    '<h2 class="nv-extra-tit">Como citar</h2>' +
    '<div class="nv-citar-abas" role="tablist">' +
      '<button type="button" class="ativa" data-fmt="abnt" role="tab" aria-selected="true">ABNT</button>' +
      '<button type="button" data-fmt="bib" role="tab" aria-selected="false">BibTeX</button></div>' +
    '<div class="nv-citar-caixa" data-fmt="abnt"><p>' + ref + "</p></div>" +
    '<div class="nv-citar-caixa" data-fmt="bib" hidden><pre>' + esc(bib) + "</pre></div>" +
    '<button type="button" class="nv-share nv-citar-copiar"><i class="bi bi-clipboard" aria-hidden="true"></i> Copiar citação</button>';
  var fmt = "abnt";
  citar.querySelectorAll(".nv-citar-abas button").forEach(function (b) {
    b.addEventListener("click", function () {
      fmt = b.dataset.fmt;
      citar.querySelectorAll(".nv-citar-abas button").forEach(function (x) {
        x.classList.toggle("ativa", x === b); x.setAttribute("aria-selected", x === b);
      });
      citar.querySelectorAll(".nv-citar-caixa").forEach(function (c) { c.hidden = c.dataset.fmt !== fmt; });
    });
  });
  citar.querySelector(".nv-citar-copiar").addEventListener("click", function () { copiar(fmt === "abnt" ? refTxt : bib, this); });

  /* ---------- Compartilhe ---------- */
  var txt = encodeURIComponent(titulo + " | " + SITE);
  var u = encodeURIComponent(url);
  var share = el("section", "nv-extra nv-compartilhar");
  share.innerHTML =
    '<h2 class="nv-extra-tit">Compartilhe</h2><div class="nv-share-botoes">' +
    '<a class="nv-share" href="https://wa.me/?text=' + txt + "%20" + u + '" target="_blank" rel="noopener"><i class="bi bi-whatsapp" aria-hidden="true"></i> WhatsApp</a>' +
    '<a class="nv-share" href="https://www.linkedin.com/sharing/share-offsite/?url=' + u + '" target="_blank" rel="noopener"><i class="bi bi-linkedin" aria-hidden="true"></i> LinkedIn</a>' +
    '<a class="nv-share" href="https://x.com/intent/post?text=' + txt + "&url=" + u + '&via=gecomt_ufersa" target="_blank" rel="noopener"><i class="bi bi-twitter-x" aria-hidden="true"></i> X</a>' +
    '<a class="nv-share" href="mailto:?subject=' + txt + "&body=" + u + '"><i class="bi bi-envelope" aria-hidden="true"></i> E-mail</a>' +
    '<button type="button" class="nv-share" data-copiar-link><i class="bi bi-link-45deg" aria-hidden="true"></i> Copiar link</button></div>';
  share.querySelector("[data-copiar-link]").addEventListener("click", function () { copiar(url, this); });

  var bloco = el("div", "nv-pos-post");
  bloco.appendChild(citar);
  bloco.appendChild(share);
  antesDoTopo(bloco);
})();
