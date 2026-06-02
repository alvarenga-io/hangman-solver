:- module(estado, [iniciar_partida/2, categoria/1, tamanho/1, candidato/1, tentadas/1, padrao/1, vidas/1]); %cria o modulo e exporta os predicados para que outro arquivos possam usá-los

% predicados dinâmicos que registram o estado atual do jogo, são modificados durante a execução (assert/retract)
:- dynamic categoria/1.
:- dynamic tamanho/1.
:- dynamic candidatos/1.    %palavras que ainda não foram descartadas
:- dynamic tentadas/1.      %letras já tentadas.
:- dynamic padrao/1.        %letras já reveladas (ex. [g ,_ ,t ,o ])
:- dynamic vidas/1.         

iniciar_partida(Categoria, Tamanho) :-
    retractall(categoria(_)), retractall(tamanho(_)),retractall(candidatos(_)),retractall(tentadas(_)),retractall(padrao(_)), retractall(vidas(_)), % 1 - reseta todos os registros de partidas anteriores
    %findall(Template, Goal, Bag)

    findall(P, (word(Categoria,P), atom_length(P, Tamanho)), CandidatosIniciais), % 2 - busca todas as palavras do tamanho especificado dentro daquela categoria

    % 3 - Cria o estado inicla na memória temporária
    assert(categoria(Categoria)),
    assert(tamanho(Tamanho)),
    assert(candidato(CandidatosIniciais)),
    assert(tentadas([])),
    assert(vidas(6)),
    length(Padrao, Tamanho),maplist (=(_),), %criar uma lista chamada Padrao com n de elementos igual à "Tamanho" . O maplist força todos os elementos na linha a serem _ 
    assert(padrao(Padrao)).

    