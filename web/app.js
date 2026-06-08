const API = "http://localhost:8080/api";

// ---------------------------------------------------------------------------
// Estado local da UI
// ---------------------------------------------------------------------------

const ui = {
  fase: "configuracao", // "configuracao" | "jogando" | "fim"
  letraAtual: null,
  tamanho: 0,
  posicoesAtivadas: new Set(),
};

// ---------------------------------------------------------------------------
// Referências aos elementos do DOM
// ---------------------------------------------------------------------------

const els = {
  // Seção de configuração
  telaConfig:       () => document.getElementById("tela-config"),
  selectCategoria:  () => document.getElementById("categoria-real"),
  inputTamanho:     () => document.getElementById("input-tamanho"),
  btnIniciar:       () => document.getElementById("btn-iniciar"),
  erroConfig:       () => document.getElementById("erro-config"),

  // Seção de jogo
  telaJogo:         () => document.getElementById("tela-jogo"),
  categoria:        () => document.getElementById("categoria"),
  imagem:           () => document.getElementById("imagem"),
  palavraSecreta:   () => document.getElementById("palavra-secreta"),
  letrasErradas:    () => document.getElementById("letras-erradas"),
  contadorCands:    () => document.getElementById("contador-candidatos"),
  balaoLetra:       () => document.getElementById("balao-letra"),
  letraDestaque:    () => document.getElementById("letra-destaque"),
  gridPosicoes:     () => document.getElementById("grid-posicoes"),
  btnSim:           () => document.getElementById("btn-sim"),
  btnNao:           () => document.getElementById("btn-nao"),
  mensagemStatus:   () => document.getElementById("mensagem-status"),

  // Seção de fim de jogo
  telaFim:          () => document.getElementById("tela-fim"),
  tituloFim:        () => document.getElementById("titulo-fim"),
  mensagemFim:      () => document.getElementById("mensagem-fim"),
  btnReiniciar:     () => document.getElementById("btnReiniciar"),
};

// ---------------------------------------------------------------------------
// Inicialização
// ---------------------------------------------------------------------------

document.addEventListener("DOMContentLoaded", () => {
  mostrarTela("configuracao");
  els.btnIniciar().addEventListener("click", iniciarPartida);
  els.btnSim().addEventListener("click", responderSim);
  els.btnNao().addEventListener("click", responderNao);
  els.btnReiniciar().addEventListener("click", reiniciar);
});

// ---------------------------------------------------------------------------
// Navegação entre telas
// ---------------------------------------------------------------------------

function mostrarTela(tela) {

  const telaFim = document.getElementById("tela-fim");
  if (telaFim) {
    if (tela === "fim") {
      telaFim.classList.remove("escondido");
    } else {
      telaFim.classList.add("escondido");
    }
  }
  ui.fase = tela;
}

// ---------------------------------------------------------------------------
// 1. Iniciar partida
// ---------------------------------------------------------------------------

async function iniciarPartida() {
  const cat  = els.selectCategoria().value;
  const tam  = parseInt(els.inputTamanho().value, 10);

  // Validação básica
  if (!cat) {
    mostrarErroConfig("Escolha uma categoria.");
    return;
  }
  if (!tam || tam < 2 || tam > 30) {
    mostrarErroConfig("Informe um número de letras entre 2 e 30.");
    return;
  }
  ocultarErroConfig();

  ui.tamanho = tam;

  els.btnIniciar().disabled = true;
  els.btnIniciar().textContent = "Iniciando...";

  try {
    const resp = await fetch(`${API}/iniciar`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ categoria: cat, tamanho: tam }),
    });
    const data = await resp.json();

    if (data.status !== "ok") {
      mostrarErroConfig(
        data.mensagem ||
        "Nenhuma palavra encontrada para essa combinação. Tente outros valores."
      );
      els.btnIniciar().disabled = false;
      els.btnIniciar().textContent = "Iniciar";
      return;
    }

    // Configura a UI de jogo
    const nomeCat = { animal: "Animal 🐾", fruta: "Fruta 🍉", pais: "País 🌍" };
    els.categoria().textContent = nomeCat[cat] || cat;
    atualizarPadrao(Array(tam).fill("_"));
    atualizarVidas(6);
    atualizarCandidatos(data.candidatos);
    limparLetrasErradas();

    mostrarTela("jogando");
    await solicitarProximaLetra();
  } catch (e) {
    mostrarErroConfig("Não foi possível conectar ao servidor Prolog. Certifique-se de que ele está rodando na porta 8080.");
    els.btnIniciar().disabled = false;
    els.btnIniciar().textContent = "Iniciar";
  }
}


// MENU INTERATIVO 
const gatilho = document.querySelector('.select-label');
const customSelect = document.querySelector('.select-customizado');
const opcoes = document.querySelectorAll('.opcao');
const selectReal = document.getElementById('categoria-real');

// Abre e fecha o menu ao clicar
gatilho.addEventListener('click', () => {
customSelect.classList.toggle('aberto');
});

// Quando clicar em uma opção
opcoes.forEach(opcao => {
opcao.addEventListener('click', () => {
    // Atualiza o texto visível
    gatilho.textContent = opcao.textContent;
    // Atualiza o valor no select escondido
    selectReal.value = opcao.getAttribute('data-value');
    // Fecha o menu
    customSelect.classList.remove('aberto');
});
});

// Fecha o menu se clicar fora dele
window.addEventListener('click', (e) => {
if (!customSelect.contains(e.target)) {
    customSelect.classList.remove('aberto');
}
});


// ---------------------------------------------------------------------------
// 2. Solicitar próxima letra ao Prolog
// ---------------------------------------------------------------------------

async function solicitarProximaLetra() {
  desabilitarResposta();

  try {
    const resp = await fetch(`${API}/proxima`);
    const data = await resp.json();

    if (!data.letra) {
      // Alfabeto esgotado — impossível
      encerrarJogo("impossivel", null);
      return;
    }

    ui.letraAtual = data.letra.toUpperCase();
    ui.posicoesAtivadas.clear();

    els.letraDestaque().textContent = ui.letraAtual;
    construirGridPosicoes(ui.tamanho);
    habilitarResposta();
  } catch (e) {
    exibirStatusErro("Erro ao comunicar com o servidor.");
  }
}

// ---------------------------------------------------------------------------
// 3a. Usuário clica "Sim" — a letra está na palavra
// ---------------------------------------------------------------------------

function responderSim() {
  const posicoes = Array.from(ui.posicoesAtivadas).sort((a, b) => a - b);

  if (posicoes.length === 0) {
    els.mensagemStatus().textContent =
      "Selecione pelo menos uma posição antes de confirmar!";
    els.mensagemStatus().className = "status-aviso";
    return;
  }

  enviarResposta(ui.letraAtual.toLowerCase(), true, posicoes);
}

// ---------------------------------------------------------------------------
// 3b. Usuário clica "Não" — a letra NÃO está na palavra
// ---------------------------------------------------------------------------

function responderNao() {
  enviarResposta(ui.letraAtual.toLowerCase(), false, []);
}

// ---------------------------------------------------------------------------
// 4. Enviar resposta ao servidor e processar resultado
// ---------------------------------------------------------------------------

async function enviarResposta(letra, acertou, posicoes) {
  desabilitarResposta();
  els.mensagemStatus().textContent = "";

  try {
    const resp = await fetch(`${API}/responder`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ letra, acertou, posicoes }),
    });
    const data = await resp.json();

    // Atualiza o display com o novo estado
    atualizarPadrao(data.padrao);
    atualizarVidas(data.vidas);
    atualizarCandidatos(data.candidatos);

    if (!acertou) {
      adicionarLetraErrada(letra.toUpperCase());
    }

    switch (data.resultado) {
      case "ganhou":
        encerrarJogo("ganhou", data.palavra);
        break;
      case "perdeu":
        encerrarJogo("perdeu", null);
        break;
      case "impossivel":
        encerrarJogo("impossivel", null);
        break;
      case "continua":
      default:
        await solicitarProximaLetra();
        break;
    }
  } catch (e) {
    exibirStatusErro("Erro ao comunicar com o servidor.");
    habilitarResposta();
  }
}

// ---------------------------------------------------------------------------
// 5. Encerrar o jogo
// ---------------------------------------------------------------------------

function encerrarJogo(resultado, palavra) {
  mostrarTela("fim");

  const titulos = {
    ganhou:      "🎉 Acertei!",
    perdeu:      "💀 Game Over",
    impossivel:  "🤔 Contradição!",
  };

  const mensagens = {
    ganhou:     `A palavra era "${(palavra || "").toUpperCase()}". O motor Prolog venceu!`,
    perdeu:     "As vidas acabaram. Vença da próxima vez!",
    impossivel: "Nenhuma palavra é compatível com as respostas fornecidas. Verifique se informou as posições corretamente.",
  };

  els.tituloFim().textContent   = titulos[resultado]  || "Fim de jogo";
  els.mensagemFim().textContent = mensagens[resultado] || "";
  els.tituloFim().className = resultado; // para estilização via CSS
}

// ---------------------------------------------------------------------------
// 6. Reiniciar
// ---------------------------------------------------------------------------

function reiniciar() {
  els.btnIniciar().disabled = false;
  els.btnIniciar().textContent = "Iniciar";
  els.inputTamanho().value = "";
  ui.letraAtual = null;
  ui.posicoesAtivadas.clear();
  mostrarTela("configuracao");
}

// ---------------------------------------------------------------------------
// Helpers de UI — Padrão de letras
// ---------------------------------------------------------------------------

function atualizarPadrao(padrao) {
  const container = els.palavraSecreta();
  container.innerHTML = "";

  padrao.forEach((ch) => {
    const span = document.createElement("span");
    span.classList.add("letras-secretas");
    span.textContent = ch === "_" ? "" : ch.toUpperCase();
    container.appendChild(span);
  });
}

// ---------------------------------------------------------------------------
// Helpers de UI — Vidas (forca)
// ---------------------------------------------------------------------------

function atualizarVidas(vidas) {
  const erros = 6 - vidas;
  // A imagem de fundo é controlada via classe CSS no elemento #imagem
  // Cada estágio corresponde a uma imagem numerada (forca-0.png … forca-6.png)
  const imgDiv = els.imagem();
  imgDiv.dataset.erros = erros;
  imgDiv.className = `forca-estagio-${erros}`;
}

// ---------------------------------------------------------------------------
// Helpers de UI — Letras erradas
// ---------------------------------------------------------------------------

function limparLetrasErradas() {
  const cont = els.letrasErradas();
  if (cont) cont.innerHTML = "";
}

function adicionarLetraErrada(letra) {
  const cont = els.letrasErradas();
  if (!cont) return;
  const span = document.createElement("span");
  span.classList.add("letra-errada");
  span.textContent = letra;
  cont.appendChild(span);
}

// ---------------------------------------------------------------------------
// Helpers de UI — Contador de candidatos
// ---------------------------------------------------------------------------

function atualizarCandidatos(n) {
  const el = els.contadorCands();
  if (el) el.textContent = `${n} palavra${n !== 1 ? "s" : ""} candidata${n !== 1 ? "s" : ""}`;
}

// ---------------------------------------------------------------------------
// Helpers de UI — Grid de posições clicáveis
// ---------------------------------------------------------------------------

function construirGridPosicoes(tamanho) {
  const grid = els.gridPosicoes();
  grid.innerHTML = "";
  

  for (let i = 1; i <= tamanho; i++) {
    const btn = document.createElement("button");
    btn.classList.add("btn-posicao");
    btn.textContent = i;
    btn.dataset.pos = i;

    btn.addEventListener("click", () => {
      if (ui.posicoesAtivadas.has(i)) {
        ui.posicoesAtivadas.delete(i);
        btn.classList.remove("ativa");
      } else {
        ui.posicoesAtivadas.add(i);
        btn.classList.add("ativa");
      }
      els.mensagemStatus().textContent = ""; // limpa aviso ao selecionar
      
    });
    
    grid.appendChild(btn);
    
  }
}

// ---------------------------------------------------------------------------
// Helpers de UI — Habilitar / Desabilitar respostas
// ---------------------------------------------------------------------------

function habilitarResposta() {
  els.btnSim().disabled = false;
  els.btnNao().disabled = false;
}

function desabilitarResposta() {
  els.btnSim().disabled = true;
  els.btnNao().disabled = true;
}

// ---------------------------------------------------------------------------
//  Mensagens de erro / status
// ---------------------------------------------------------------------------

function mostrarErroConfig(msg) {
  const el = els.erroConfig();
  if (el) {
    el.textContent = msg;
    el.classList.remove("escondido");
  }
}

function ocultarErroConfig() {
  const el = els.erroConfig();
  if (el) el.classList.add("escondido");
}

function exibirStatusErro(msg) {
  const el = els.mensagemStatus();
  if (el) {
    el.textContent = msg;
    el.className = "status-erro";
  }
}
