 % Núcleo do solver — filtragem de candidatos e atualização do padrão.
 % Predicados Principais: 

%   - filtrar_candidatos/2  remove palavras incompatíveis com uma letra CONFIRMADA
%   - filtrar_candidatos_ausente/1  remove palavras que contêm uma letra AUSENTE
%   - atualizar_padrao/2   preenche as posições reveladas no padrão
:- use_module(library(lists)).
:- use_module(library(apply)).
:- ensure_loaded('estado').


filtrar_candidatos(Letra,Posicoes) :-
    candidatos(Lista),
    % include(:Teste, +Lista, -LitaFiltrada)
    %       : Indica que este argumento deve ser um predicado (uma regra de teste).
    %       + Indica que o argumento deve ser passado já preenchido.
    %       - Indica que o argumento é uma variável vazia que vai receber o resultado de saída.
    % Cria uma nova lista que mantém apenas os elementos da lsita antiga compatíveis com a nova informação de letra e posição.
    include(compativel(Letra,Posicoes), Lista, Nova), 
    
    retract(candidatos(_)),
    assert(candidatos(Nova)).

% Predicado Auxilar: testar palavras compatíveis com as novas informações passadas 
%   Retorna verdadeiro quando as posições reais de "Letra" em "Palavra" são igual ao conjunto "Posicoes"

compativel(Letra, Posicoes, Palavra) :-
    atom_chars(Palavra, Chars), % ex. ?- atom_chars(gato, Chars).
%                                 Chars = [g,a,t,o].
    posicoes_da_letra(Letra, Chars, PosReais),
    msort(Posicoes, PosOrd),
    msort(PosReais, PorOrd).

posicoes_da_letra(Letra, Chars, Posicoes) :-
    findall(Index, nth1(Index, Chars, Letra), Posicoes). % ?- nth1(Idx, [g, a, t, a], a).
 %                                                               Idx = 2 ;
 %                                                               Idx = 4.

% filtrar_candidatos_ausente(+Letra)
%   Remove todos os candidatos que CONTÊM Letra.
filtrar_candidados_ausentes(Letra):-
    candidatos(Lista),
    exclude(contem_letra(Letra), Lista, Nova),
    retract(candidatos(_)),
    assertz(candidatos(Nova)).

% contem_letra(+Letra, +Palavra)
%   Retorna verdadeiro se "Letra" aparece pelo menos uma vez em na "Palavra" passada.
contem_letra(Letra, Palavra) :-
    atom_chars(Palavra, Chars),
    member(Letra, Chars).

atualizar_padrao(Letra, Posicao) :-
    ratract(padrao(PadraoAntigo)),
    findall(Elemento, (
            nth1(Index, PadraoAntigo, ValorAntigo),
            (member(Index, Posicoes) -> Elemento = Letra: Elemento = PadraoAntigo)),
            NovoPadrao),
    assertz(padrao(NovoPadrao)).
        