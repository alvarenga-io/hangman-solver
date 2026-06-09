% estado.pl
% Estado dinâmico do jogo — predicados que mudam a cada rodada.

:- use_module(library(lists)).
:- use_module(library(apply)).  %carrega predicados de altas ordem como inlcude/3

:- ensure_loaded('palavras/animais').
:- ensure_loaded('palavras/frutas').
:- ensure_loaded('palavras/paises').

% ---------------------------------------------------------------------------
% Predicados dinâmicos — representam o estado atual da partida
% ---------------------------------------------------------------------------

:- dynamic categoria/1.   % átomo: animal | fruta | pais
:- dynamic tamanho/1.     % inteiro: número de letras da palavra
:- dynamic candidatos/1.  % lista de átomos: palavras ainda possíveis
:- dynamic tentadas/1.    % lista de átomos (chars): letras já sugeridas
:- dynamic padrao/1.      % lista de chars/átomos: letras reveladas ou '_'
:- dynamic vidas/1.       % inteiro 0-6: tentativas restantes

% iniciar_jogo(+Categoria, +Tamanho)

iniciar_jogo(Cat, Tam) :-
    % Limpa estado anterior
    retractall(categoria(_)),
    retractall(tamanho(_)),
    retractall(candidatos(_)),
    retractall(tentadas(_)),
    retractall(padrao(_)),
    retractall(vidas(_)),


    %findall(Template, Goal, Bag)
    % 2 - busca todas as palavras do tamanho especificado dentro daquela categoria e armazena na lsita "CandidatosIniciais"
    findall(P, (palavra(Cat, P), atom_length(P, Tam)), Cands),

    % Padrão inicial: lista de '_' com Tam elementos
    length(Padrao, Tam), %Criar uma lista chamada Padrao de tamanho 4 com todos os elementos vazios .
    maplist(=('_'), Padrao),

    % Persiste o estado inicial
    assertz(categoria(Cat)),
    assertz(tamanho(Tam)),
    assertz(candidatos(Cands)),
    assertz(tentadas([])),
    assertz(padrao(Padrao)),
    assertz(vidas(6)).

% Operações de atualização de estado

% Decrementa uma vida após erro
decrementar_vida :-
    retract(vidas(V)),
    V1 is V - 1,
    assertz(vidas(V1)).

% Registra uma letra como já tentada
registrar_tentada(Letra) :-
    retract(tentadas(T)),
    assertz(tentadas([Letra|T])).

% consultar_estado/1  — debug 
%   ?- consultar_estado(completo).

consultar_estado(completo) :-
    categoria(Cat),    format("Categoria : ~w~n", [Cat]),  %Consulta o banco de dados para carregar valor a variável antes de formatar a exibição
    tamanho(Tam),      format("Tamanho   : ~w~n", [Tam]),
    vidas(V),          format("Vidas     : ~w~n", [V]),
    tentadas(T),       format("Tentadas  : ~w~n", [T]),
    padrao(P),         format("Padrao    : ~w~n", [P]),
    candidatos(C),
    length(C, N),      format("Candidatos: ~w (~w palavras)~n", [C, N]).