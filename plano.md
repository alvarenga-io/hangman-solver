# Plano de Projeto — Hangman Solver em Prolog + Interface Web

> **Público-alvo:** Estudantes de Lógica Computacional / Prolog  
> **Modalidade:** MVP pedagógico — foco na modelagem lógica, não na engenharia de produção  
> **Duração estimada:** 3–4 semanas (individual ou dupla)

---

## 1. Visão Geral

O projeto implementa um **agente solucionador de Forca** em que os papéis são invertidos: o **humano pensa** na palavra secreta e a **máquina (Prolog) tenta adivinhar**, uma letra por vez, de forma inteligente.

### Fluxo Macro

```
[Usuário]                         [Sistema]
  │                                   │
  ├── escolhe categoria ──────────────►│
  ├── pensa/digita a palavra ─────────►│ (Prolog NÃO vê a palavra)
  ├── informa nº de letras ────────────►│
  │                                   │
  │◄── tenta letra L ─────────────────┤  ← Motor Prolog
  │                                   │
  ├── informa posições de L ──────────►│
  │                                   │
  │◄── tenta próxima letra ───────────┤  (filtra candidatos)
  │       ... loop ...                │
  │                                   │
  │◄── "A palavra é X!" ──────────────┤  (ou: "Perdi!")
```

---

## 2. Objetivos de Aprendizagem

| # | Conceito Prolog | Onde Aparece no Projeto |
|---|-----------------|------------------------|
| 1 | Unificação e pattern matching | Filtragem de candidatos por padrão de letras |
| 2 | Listas e recursão | Percorrer e filtrar banco de palavras |
| 3 | Backtracking controlado | Estratégia de tentativas |
| 4 | Assertiva dinâmica (`assert/retract`) | Estado do jogo em tempo de execução |
| 5 | Corte (`!`) | Evitar recomputação desnecessária |
| 6 | Metapredicados (`include/3`, `maplist/2`) | Filtragem funcional da lista de candidatos |

---

## 3. Arquitetura do Sistema

```
hangman-solver/
│
├── prolog/
│   ├── palavras/
│   │   ├── animais.pl          % base de fatos: word(animal, "gato").
│   │   ├── frutas.pl
│   │   └── paises.pl
│   │
│   ├── motor.pl               % núcleo do solver
│   ├── estrategia.pl             % seleção de letra a tentar
│   ├── estado.pl                % estado dinâmico do jogo
│   └── server.pl               % servidor HTTP (SWI-Prolog http)
│
├── web/
│   ├── index.html              % interface do jogador
│   ├── style.css
│   └── app.js                  % lógica de comunicação com o servidor
│
└── README.md
```

---

## 4. Modelagem Lógica em Prolog

### 4.1 Base de Conhecimento — Palavras

```prolog
% words/animais.pl
:- module(animais, [word/2]).

word(animal, gato).
word(animal, lobo).
word(animal, zebra).
word(animal, onca).
word(animal, coelho).
% ... mínimo 30 palavras por categoria
```

> **Tarefa dos estudantes:** Completar as bases com pelo menos 30 entradas por categoria.

---

### 4.2 Estado Dinâmico — `state.pl`

```prolog
% state.pl — predicados dinâmicos que representam o estado atual do jogo

:- dynamic categoria/1.          % categoria escolhida
:- dynamic tamanho/1.            % número de letras
:- dynamic candidatos/1.         % lista de palavras ainda possíveis
:- dynamic tentadas/1.           % letras já tentadas
:- dynamic padrao/1.             % ex: [g, _, t, o] (letras reveladas)
:- dynamic vidas/1.              % tentativas restantes (padrão: 6)

% Inicializa o jogo para uma categoria e tamanho informados
iniciar_jogo(Categoria, Tamanho) :-
    retractall(candidatos(_)),
    retractall(tentadas(_)),
    retractall(padrao(_)),
    retractall(vidas(_)),
    findall(P, (word(Categoria, P), atom_length(P, Tamanho)), Candidatos),
    assert(categoria(Categoria)),
    assert(tamanho(Tamanho)),
    assert(candidatos(Candidatos)),
    assert(tentadas([])),
    length(Padrao, Tamanho), maplist(=(_), Padrao),
    assert(padrao(Padrao)),
    assert(vidas(6)).
```

---

### 4.3 Motor de Filtragem — `engine.pl`

> Este é o **coração pedagógico** do projeto.

```prolog
% engine.pl

:- use_module(state).

% Filtra candidatos com base na resposta do usuário.
% Letra L aparece nas posições em Posicoes (lista 1-based).
% Remove da lista qualquer palavra incompatível com essa informação.

filtrar_candidatos(Letra, Posicoes) :-
    candidatos(Lista),
    include(compativel(Letra, Posicoes), Lista, Nova),
    retract(candidatos(_)),
    assert(candidatos(Nova)).

% Um candidato Palavra é compatível se:
%   - A Letra aparece em todas as posições declaradas
%   - A Letra NÃO aparece em posições não declaradas
compativel(Letra, Posicoes, Palavra) :-
    atom_chars(Palavra, Chars),
    posicoes_da_letra(Letra, Chars, PosReais),
    msort(Posicoes, PosOrd),
    msort(PosReais, PosOrd).   % as posições devem ser exatamente iguais

% Calcula as posições (1-based) em que Letra aparece em Chars
posicoes_da_letra(Letra, Chars, Posicoes) :-
    posicoes_da_letra(Letra, Chars, 1, Posicoes).

posicoes_da_letra(_, [], _, []).
posicoes_da_letra(Letra, [Letra|T], N, [N|Rest]) :-
    !,
    N1 is N + 1,
    posicoes_da_letra(Letra, T, N1, Rest).
posicoes_da_letra(Letra, [_|T], N, Rest) :-
    N1 is N + 1,
    posicoes_da_letra(Letra, T, N1, Rest).

% Atualiza o padrão visível quando uma letra é confirmada
atualizar_padrao(Letra, Posicoes) :-
    padrao(Padrao),
    atualizar_lista(Padrao, Letra, Posicoes, 1, NovoPadrao),
    retract(padrao(_)),
    assert(padrao(NovoPadrao)).

atualizar_lista([], _, _, _, []).
atualizar_lista([_|T], Letra, Posicoes, N, [Letra|Rest]) :-
    member(N, Posicoes), !,
    N1 is N + 1,
    atualizar_lista(T, Letra, Posicoes, N1, Rest).
atualizar_lista([H|T], Letra, Posicoes, N, [H|Rest]) :-
    N1 is N + 1,
    atualizar_lista(T, Letra, Posicoes, N1, Rest).
```

---

### 4.4 Estratégia de Tentativas — `strategy.pl`

```prolog
% strategy.pl — escolhe qual letra tentar a seguir

:- use_module(state).
:- use_module(engine).

% Escolhe a letra mais frequente entre os candidatos atuais,
% que ainda não foi tentada.
proxima_letra(Letra) :-
    candidatos(Candidatos),
    tentadas(Tentadas),
    contar_frequencias(Candidatos, Tentadas, Freq),
    max_member(_-Letra, Freq), !.

% Conta quantas palavras candidatas contêm cada letra não tentada
contar_frequencias(Candidatos, Tentadas, FreqOrdenada) :-
    atom_chars(abcdefghijklmnopqrstuvwxyz, Alphabet),
    subtract(Alphabet, Tentadas, Disponiveis),
    findall(
        Contagem-Letra,
        (
            member(Letra, Disponiveis),
            include(contem_letra(Letra), Candidatos, Sub),
            length(Sub, Contagem),
            Contagem > 0
        ),
        FreqOrdenada
    ).

contem_letra(Letra, Palavra) :-
    atom_chars(Palavra, Chars),
    member(Letra, Chars).

% Após processar resposta, decide: jogo ganho, perdido ou continua
verificar_estado(Resultado) :-
    (   candidatos([Palavra]) ->
        Resultado = ganhou(Palavra)
    ;   candidatos([]) ->
        Resultado = impossivel   % contradição: usuário errou ao confirmar?
    ;   vidas(0) ->
        Resultado = perdeu
    ;   Resultado = continua
    ).
```

---

### 4.5 Servidor HTTP — `server.pl`

```prolog
% server.pl — expõe o motor via HTTP (SWI-Prolog)

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(engine).
:- use_module(strategy).
:- use_module(state).

:- http_handler('/api/iniciar',      handle_iniciar,      []).
:- http_handler('/api/proxima',      handle_proxima,      []).
:- http_handler('/api/responder',    handle_responder,    []).
:- http_handler('/api/estado',       handle_estado,       []).

server(Port) :-
    http_server(http_dispatch, [port(Port)]).

:- initialization(server(8080), main).

% POST /api/iniciar  { categoria, tamanho }
handle_iniciar(Request) :-
    http_read_json_dict(Request, Body),
    iniciar_jogo(Body.categoria, Body.tamanho),
    reply_json_dict(_{status: ok}).

% GET /api/proxima  → { letra }
handle_proxima(_Request) :-
    proxima_letra(Letra),
    atom_string(Letra, LetraStr),
    reply_json_dict(_{letra: LetraStr}).

% POST /api/responder  { letra, posicoes, acertou }
handle_responder(Request) :-
    http_read_json_dict(Request, Body),
    (   Body.acertou = true
    ->  filtrar_candidatos(Body.letra, Body.posicoes),
        atualizar_padrao(Body.letra, Body.posicoes)
    ;   decrementar_vida,
        filtrar_candidatos_ausente(Body.letra)
    ),
    registrar_tentada(Body.letra),
    verificar_estado(Resultado),
    resultado_json(Resultado, RJson),
    reply_json_dict(RJson).

% GET /api/estado  → { candidatos, padrao, vidas, tentadas }
handle_estado(_Request) :-
    candidatos(C), padrao(P), vidas(V), tentadas(T),
    reply_json_dict(_{candidatos: C, padrao: P, vidas: V, tentadas: T}).
```

---

## 5. Interface Web

### Responsabilidades do `app.js`

- Coletar categoria e número de letras do usuário
- Enviar `POST /api/iniciar` ao carregar o jogo
- A cada rodada:
  1. `GET /api/proxima` → exibir a letra tentada pelo Prolog
  2. Usuário confirma: "Acertou?" + quais posições
  3. `POST /api/responder` com as informações
  4. Atualizar display (padrão, vidas, candidatos restantes — opcional)
- Exibir resultado final (ganhou/perdeu)

### Componentes Visuais Mínimos

```
┌──────────────────────────────────────────────┐
│  🎯  HANGMAN SOLVER — Prolog Edition          │
├──────────────────────────────────────────────┤
│  Categoria: [ Animal ▼ ]  Letras: [ 4 ]  [▶] │
├──────────────────────────────────────────────┤
│                                              │
│   Padrão atual:   _ A T _                   │
│   Vidas:          ❤️❤️❤️❤️❤️💀                │
│                                              │
│   Prolog pergunta:  "A letra é  **O** ?"    │
│                                              │
│   [✅ Sim — posições: 1 4 ]  [❌ Não]        │
│                                              │
│   Candidatos restantes: 3                   │
└──────────────────────────────────────────────┘
```

---

## 6. Roteiro de Implementação (Sprints)

### Sprint 0 — Setup (Dia 1–2)

- [ ] Instalar SWI-Prolog (`swipl`)
- [ ] Clonar estrutura de diretórios do projeto
- [ ] Testar o servidor HTTP com um endpoint `/ping`
- [ ] Verificar comunicação JS → Prolog via `fetch`

**Entregável:** Servidor rodando e respondendo JSON no browser.

---

### Sprint 1 — Base de Conhecimento (Dia 3–5)

- [ ] Implementar `words/animais.pl` (≥ 30 palavras)
- [ ] Implementar `words/frutas.pl` (≥ 20 palavras)
- [ ] Implementar `words/paises.pl` (≥ 20 palavras)
- [ ] Testar `findall` filtrando por categoria e tamanho no REPL

**Entregável:** Consulta `?- findall(P, (word(animal, P), atom_length(P, 4)), L).` retorna lista correta.

---

### Sprint 2 — Motor de Jogo (Dia 6–10)

- [ ] Implementar `state.pl` com predicados dinâmicos
- [ ] Implementar `engine.pl` — `compativel/3` e `filtrar_candidatos/2`
- [ ] Implementar `strategy.pl` — `proxima_letra/1`
- [ ] Testar todo o ciclo no REPL sem interface

**Sessão de teste no REPL:**
```prolog
?- iniciar_jogo(animal, 4).
?- proxima_letra(L).           % L = a (letra mais frequente)
?- filtrar_candidatos(a, [2]). % 'a' está só na posição 2
?- candidatos(C).              % lista filtrada
```

**Entregável:** Ciclo completo funciona no terminal Prolog.

---

### Sprint 3 — API HTTP (Dia 11–14)

- [ ] Implementar os 4 endpoints em `server.pl`
- [ ] Testar com `curl` ou Postman:

```bash
# Iniciar jogo
curl -X POST http://localhost:8080/api/iniciar \
     -H "Content-Type: application/json" \
     -d '{"categoria":"animal","tamanho":4}'

# Pedir próxima letra
curl http://localhost:8080/api/proxima

# Responder (acertou, posições 2 e 4)
curl -X POST http://localhost:8080/api/responder \
     -H "Content-Type: application/json" \
     -d '{"letra":"a","posicoes":[2,4],"acertou":true}'
```

**Entregável:** API responde corretamente a todos os endpoints.

---

### Sprint 4 — Interface Web (Dia 15–18)

- [ ] Criar `index.html` com os componentes mínimos
- [ ] Implementar `app.js` com o ciclo de perguntas e respostas
- [ ] Conectar visualmente o padrão de letras, vidas e candidatos
- [ ] Tratar estados finais (ganhou / perdeu / contradição)

**Entregável:** Jogo completo jogável no browser.

---

### Sprint 5 — Testes e Reflexão (Dia 19–21)

- [ ] Jogar 5 partidas completas e anotar comportamento
- [ ] Testar casos-limite:
  - Palavra única na categoria com aquele tamanho
  - Usuário comete erro ao informar posições
  - Prolog esgota as letras do alfabeto
- [ ] Escrever relatório de reflexão (ver Seção 8)

---

## 7. Critérios de Avaliação do MVP

| Critério | Peso | Evidência Esperada |
|----------|------|--------------------|
| Base de conhecimento completa | 10% | ≥ 30 palavras por categoria |
| `compativel/3` correto | 25% | Filtra exatamente os candidatos esperados |
| `proxima_letra/1` inteligente | 20% | Escolhe com base em frequência, não aleatoriamente |
| API HTTP funcional | 20% | Todos os endpoints respondem JSON válido |
| Interface jogável | 15% | Ciclo completo sem erros de interface |
| Relatório de reflexão | 10% | Análise dos conceitos Prolog utilizados |

---

## 8. Reflexão Guiada (Relatório)

Ao final do projeto, responda em **1–2 parágrafos cada**:

1. **Unificação:** Como o predicado `compativel/3` usa unificação para descartar candidatos? Dê um exemplo concreto com a palavra "gato".

2. **Estado dinâmico:** Por que `assert/retract` é necessário aqui? O que aconteceria se tentássemos modelar o estado apenas com argumentos de predicados?

3. **Estratégia vs. Aleatoriedade:** Qual é a diferença entre um solver que tenta letras aleatoriamente e um que usa frequência? Em que situação a estratégia de frequência falha?

4. **Limitações:** O que o sistema NÃO consegue fazer bem? Como você melhoraria o algoritmo com mais tempo?

---

## 9. Extensões Opcionais (Bônus)

> Para estudantes que terminarem antes do prazo.

| Extensão | Conceito Prolog Envolvido |
|----------|--------------------------|
| Adicionar dicas semânticas (animal doméstico / selvagem) | Hierarquia de fatos |
| Visualizar a forca no terminal ASCII | Manipulação de strings / formatação |
| Solver com frequência baseada em corpus (não apenas candidatos) | Listas de pares, ordenação |
| Modo automático (Prolog testa contra si mesmo) | Metaprogramação |
| Exportar histórico de partidas como CSV | I/O de arquivos em Prolog |

---

## 10. Referências

- **SWI-Prolog Documentation:** https://www.swi-prolog.org/pldoc/
- **HTTP Server em SWI-Prolog:** https://www.swi-prolog.org/howto/http/
- **Learn Prolog Now! (capítulos 1–5):** https://www.let.rug.nl/bos/lpn/
- **The Art of Prolog — Sterling & Shapiro** *(capítulos sobre listas e metapredicados)*

---

> 💡 **Dica Pedagógica:** Execute **cada predicado isoladamente no REPL** (`swipl`) antes de integrá-lo ao sistema. A interatividade do Prolog é sua maior ferramenta de aprendizado.
