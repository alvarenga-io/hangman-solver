% Esse arquivo orienta os palpites do Solver 

% A estratégia consiste em escolher sempre a letra mais frequente entre os candidatos restantes, dentre as ainda não tentadas.

:- use_module(library(lists)).
:- use_module(library(apply)).
:- ensure_loaded('estado').
:- ensure_loaded('motor').

% proxima_letra(-Letra)
%   Escolhe a próxima letra a ser tentada de acordo maior frequência no conjunto de candidatos atuais,
%   excluindo letras já tentadas.

proxima_letra(Letra) :-
    candidato(Candidatos),
    tentadas(Tentadas),
    contar_frequencias(Candidatos, Tentadas, Freq),
    Freq \= [], % Verifica se a lista não está vazia
    msort(Freq, FreqOrd),
    last(FreqOrd, _-Letra), !.

contar_frequencias(Candidatos, Tentadas, FreqOrdenada) :-
    atom_chars(abcdefghijklmnopqrstuvwxyz, Alfabeto),
    subtract(Alfabeto, Tentadas, Disponiveis),
    findall (
        Contagem-Letra (                                    % O operador - é usado para criar estruturas do tipo Chave-Valor
            member(Letra, Disponiveis),                     % Seleciona uma letra disponível
            include(contem_letra(Letra), Candidados, Sub),  % Cria a lista sub com as palavras disponíveis que contém a letra
            length(Sub, Contagem),          %Conta quantas palavras estão na lista SUb
            Contagem >0                     %Só avança se a letra aparecer em pelo menos uma palavra
            ),
            FreqOrdenada
        ).

verificar_estado(Resultado) :-
    padrao(Padrao),

    % ( Se -> Entao ; Senao )

    (   \+ member('_', Padrao)
    -> atom_chars(Palavra, Padrao),
        Resultado = ganhou(Palavra)
    ;   candidados([Palavra])
    ->  Resultado = ganhou(Palavra),
    ;    candidatos([])
    ->  Resultado = impossivel
    ;   vidas(0)
        Resultado = perdeu
    ;   Resultado = continua
    ).