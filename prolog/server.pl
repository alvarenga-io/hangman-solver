% server.pl
% Servidor HTTP para o Hangman Solver.
%
%
% O servidor inicia automaticamente na porta 8080.
% Para iniciar manualmente no REPL:
%   swipl -l prolog/server.pl
%   ?- server(8080).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_files)).
:- use_module(library(lists)).
:- use_module(library(apply)).

:- ensure_loaded('estado').
:- ensure_loaded('motor').
:- ensure_loaded('estrategia').

% ---------------------------------------------------------------------------
% CORS — necessário para o browser poder chamar a API a partir de index.html
% ---------------------------------------------------------------------------

:- set_setting(http:cors, [*]).

% ---------------------------------------------------------------------------
% Roteamento dos endpoints
% ---------------------------------------------------------------------------

:- http_handler('/api/iniciar',   handle_iniciar,   [method(post)]).
:- http_handler('/api/proxima',   handle_proxima,   [method(get)]).
:- http_handler('/api/responder', handle_responder, [method(post)]).
:- http_handler('/api/estado',    handle_estado,    [method(get)]).

% Serve os arquivos estáticos da pasta web/
:- http_handler('/',
    http_reply_from_files('../web', [index('index.html')]),
    [prefix]).

% ---------------------------------------------------------------------------
% server(+Porta)
%   Inicia o servidor HTTP na porta especificada.
% ---------------------------------------------------------------------------

server(Port) :-
    http_server(http_dispatch, [port(Port)]).

:- initialization(server(8080), main).

% ---------------------------------------------------------------------------
% POST /api/iniciar
%   Body: { "categoria": "animal", "tamanho": 4 }
%   Resposta: { "status": "ok", "candidatos": 12 }
%             { "status": "erro", "mensagem": "..." }
% ---------------------------------------------------------------------------

handle_iniciar(Request) :-
    cors_enable(Request, [methods([post])]),
    catch(
        (
            http_read_json_dict(Request, Body),
            atom_string(CatAtom, Body.categoria),
            Tam = Body.tamanho,
            (   integer(Tam), Tam > 0
            ->  iniciar_jogo(CatAtom, Tam),
                candidatos(Cands),
                length(Cands, N),
                reply_json_dict(_{status: ok, candidatos: N})
            ;   reply_json_dict(_{status: erro, mensagem: "Tamanho deve ser um inteiro positivo."})
            )
        ),
        _Erro,
        reply_json_dict(_{status: erro, mensagem: "Erro ao processar requisição."})
    ).

% ---------------------------------------------------------------------------
% GET /api/proxima
%   Resposta: { "letra": "a" }
%             { "letra": null }  — alfabeto esgotado
% ---------------------------------------------------------------------------

handle_proxima(Request) :-
    cors_enable(Request, [methods([get])]),
    (   proxima_letra(Letra)
    ->  atom_string(Letra, LetraStr),
        reply_json_dict(_{letra: LetraStr})
    ;   reply_json_dict(_{letra: null})
    ).

% ---------------------------------------------------------------------------
% POST /api/responder
%   Body: { "letra": "a", "acertou": true,  "posicoes": [2, 4] }
%      ou { "letra": "z", "acertou": false, "posicoes": [] }
%
%   Resposta: { "resultado": "continua"|"ganhou"|"perdeu"|"impossivel",
%               "palavra": "gato",      ← só quando resultado = "ganhou"
%               "padrao": ["_","a","_","_"],
%               "vidas": 5,
%               "candidatos": 8 }
% ---------------------------------------------------------------------------

handle_responder(Request) :-
    cors_enable(Request, [methods([post])]),
    catch(
        (
            http_read_json_dict(Request, Body),
            atom_string(Letra, Body.letra),
            Acertou = Body.acertou,
            Posicoes = Body.posicoes,

            (   Acertou = true
            ->  (   Posicoes \= []
                ->  filtrar_candidatos(Letra, Posicoes),
                    atualizar_padrao(Letra, Posicoes)
                ;   % Posições vazias com "sim" → trata como erro (letra ausente)
                    decrementar_vida,
                    filtrar_candidatos_ausente(Letra)
                )
            ;   decrementar_vida,
                filtrar_candidatos_ausente(Letra)
            ),
            registrar_tentada(Letra),

            verificar_estado(Resultado),
            padrao(Pad),
            vidas(V),
            candidatos(Cands),
            length(Cands, NC),

            % Converte padrão de átomos para strings (JSON-friendly)
            maplist(atom_string, Pad, PadStr),

            resultado_dict(Resultado, NC, PadStr, V, RDict),
            reply_json_dict(RDict)
        ),
        _Erro,
        reply_json_dict(_{resultado: erro, mensagem: "Erro ao processar resposta."})
    ).

% ---------------------------------------------------------------------------
% GET /api/estado
%   Retorna o estado completo da partida (útil para debug / re-sincronizar UI).
%   Resposta: { "candidatos": [...], "padrao": [...], "vidas": 5,
%               "tentadas": ["a","e"], "total_candidatos": 12 }
% ---------------------------------------------------------------------------

handle_estado(Request) :-
    cors_enable(Request, [methods([get])]),
    candidatos(Cands),
    padrao(Pad),
    vidas(V),
    tentadas(Tent),
    length(Cands, N),
    maplist(atom_string, Pad,  PadStr),
    maplist(atom_string, Tent, TentStr),
    reply_json_dict(_{
        candidatos:       Cands,
        padrao:           PadStr,
        vidas:            V,
        tentadas:         TentStr,
        total_candidatos: N
    }).

% ---------------------------------------------------------------------------
% resultado_dict(+Resultado, +NCandidatos, +Padrao, +Vidas, -Dict)
%   Constrói o dicionário JSON da resposta de /api/responder.
% ---------------------------------------------------------------------------

resultado_dict(ganhou(Palavra), NC, Pad, V, Dict) :-
    atom_string(Palavra, PalavraStr),
    Dict = _{resultado: ganhou, palavra: PalavraStr,
             padrao: Pad, vidas: V, candidatos: NC}.

resultado_dict(perdeu, NC, Pad, V, Dict) :-
    Dict = _{resultado: perdeu,
             padrao: Pad, vidas: V, candidatos: NC}.

resultado_dict(impossivel, NC, Pad, V, Dict) :-
    Dict = _{resultado: impossivel,
             padrao: Pad, vidas: V, candidatos: NC}.

resultado_dict(continua, NC, Pad, V, Dict) :-
    Dict = _{resultado: continua,
             padrao: Pad, vidas: V, candidatos: NC}.