:- use_module(library(lists)). %carrega a biblioteca de manipulação de listas.
:- use_module(library(apply)). %carrega predicados de altas ordem como inlcude/3
:- ensure_loaded('palavras/animais').
:- ensure_loaded('palavras/frutas').
:- ensure_loaded('palavras/paises').


% predicados dinâmicos que registram o estado atual do jogo, são modificados durante a execução (assert/retract)
:- dynamic categoria/1.
:- dynamic tamanho/1.
:- dynamic candidatos/1.    %palavras que ainda não foram descartadas
:- dynamic tentadas/1.      %letras já tentadas.
:- dynamic padrao/1.        %letras já reveladas (ex. [g ,_ ,t ,o ])
:- dynamic vidas/1.         

iniciar_jogo(Categoria, Tamanho) :-
    % 1 - reseta todos os registros de partidas anteriores
    retractall(categoria(_)), 
    retractall(tamanho(_)),
    retractall(candidatos(_)),
    retractall(tentadas(_)),
    retractall(padrao(_)),
    retractall(vidas(_)), 

    %findall(Template, Goal, Bag)
    % 2 - busca todas as palavras do tamanho especificado dentro daquela categoria e armazena na lsita "CandidatosIniciais"

    findall(P, (palavra(Categoria,P), atom_length(P, Tamanho)), CandidatosIniciais), % Palavra é predicado dinâmico de dois argumentos usado no banco de palavras

    % 3 - Cria o estado inicla na memória temporária

    length(Padrao, Tamanho), %Criar uma lista chamada Padrao com todos os elementos de comprimento igual à "Tamanho" .
    maplist (=(_),Padrao), %O maplist força todos os elementos na linha a serem _ 

    assertz(categoria(Categoria)), %Transporta o valor Categoria informado pelo usuário para dentro do predicado categoria () criado na memória
    assertz(tamanho(Tamanho)),
    assertz(candidato(CandidatosIniciais)),
    assertz(tentadas([])),
    assertz(vidas(6)),
    assertz(padrao(Padrao)).

    % 4. Atualiza a vida conforme tentativas.
    decrementar_vida :-
        retract(vidas(V)),
        V1 is V-1,
        assertz(vidas(V1)).

    % 5. Registra tentativas
    registrar_tentadas(Letra) :- 
        retract(tentadas(T)), %O valor presentre dentro do predicado (vazio ou lista) é absorvido pela variável T.
        assertz(tentadas([Letra|T])). %O predicado recebe uma nova lista que tem "Letra" como cabeça e a lista antiga como cauda
    
    % consultar_estado/1  — debug / inspeção no REPL
%   ?- consultar_estado(completo).
    consultar_estado(completo) :-
        categoria(Categoria),   format("Categoria : ~w~n", [Categoria]), %Consulta o banco de dados para carregar valor a variável antes de formatar a exibição
        tamanho(Tamanho),       format("Tamanho: ~w~n", [Tamanho]),
        vidas(V),               format("Vidas: ~w~n", [V]),
        tentadas(Tentadas),     format("Tentadas: ~w~n"m [T]),
        padrao(P),              format("Padrao: ~w~n", [P]),
        candidatos(Candidatos), length(Candidatos, N), format("Candidatos: ~w (~w palavras)~n", [C,N]).