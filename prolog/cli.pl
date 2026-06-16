% cli.pl
% Interface de linha de comando (terminal) para o Hangman Solver.

%   swipl -l prolog/cli.pl
%   ?- jogar.

:- use_module(library(lists)).
:- use_module(library(apply)).
:- ensure_loaded('estado').
:- ensure_loaded('motor').
:- ensure_loaded('estrategia').

% Ponto de entrada automático ao rodar: swipl prolog/cli.pl
% initialization(:Goal, +When)
:- initialization(main, main).


main :-
    banner,
    jogar,
    halt(0).

jogar :-
    nova_partida,
    perguntar_jogar_novamente.

nova_partida :-
    configurar_jogo,
    loop_rodada.


loop_rodada :-
    verificar_estado(Resultado),
    (   Resultado = continua
    ->  exibir_estado,
        (   proxima_letra(Letra) % "Existe mais alguma letra para tentar?"
        ->  processar_tentativa(Letra),
            loop_rodada          % recursão: próxima rodada
        ;   % Alfabeto esgotado sem resolução
            exibir_separador,
            format("Esgotei todas as letras do alfabeto sem descobrir a palavra.~n"),
            format("Candidatos restantes: "),
            candidatos(C), format("~w~n", [C])
        )
    ;   % Jogo encerrado (ganhou / perdeu / impossivel)
        exibir_estado,
        exibir_resultado(Resultado)
    ).

% processar_tentativa(+Letra)
%   Exibe a letra sugerida, coleta resposta do usuário e atualiza o estado.

processar_tentativa(Letra) :-
    exibir_separador,
    format("  Minha tentativa: a letra e '~w'~n", [Letra]),
    nl,
    format("  A letra '~w' esta na palavra? [sim/nao]: ", [Letra]),
    ler_linha(Resp),
    nl,
    (   Resp = sim
    ->  format("  Em quais posicoes? (1-based, separados por espaco)~n"),
        format("  Exemplo: '2 4' significa posicoes 2 e 4~n"),
        format("  Posicoes: "),
        ler_posicoes(Pos),
        (   Pos \= []
        ->  filtrar_candidatos(Letra, Pos),
            atualizar_padrao(Letra, Pos)
        ;   format("  [!] Nenhuma posicao informada — tratando como 'nao'.~n"),
            decrementar_vida,
            filtrar_candidatos_ausente(Letra)
        )
    ;   % Letra ausente — descarta candidatos que a contêm
        decrementar_vida,
        filtrar_candidatos_ausente(Letra),
        format("  Letra '~w' ausente registrada.~n", [Letra])
    ),
    registrar_tentada(Letra).

% configurar_jogo/0 — coleta categoria e tamanho; inicializa o jogo

configurar_jogo :-
    nl,
    format("=== NOVA PARTIDA ===~n~n"),
    format("Pense em uma palavra secreta.~n"),
    format("Eu vou tentar adivinhar letra por letra!~n~n"),
    ler_categoria(Cat),
    ler_tamanho(Tam),
    iniciar_jogo(Cat, Tam),
    candidatos(Cands),
    length(Cands, N),
    (   N =:= 0
    ->  format("~n[!] Nenhuma palavra encontrada para a categoria '~w' com ~w letras.~n", [Cat, Tam]),
        format("    Verifique a categoria e o numero de letras e tente novamente.~n~n"),
        configurar_jogo    % reinicia a configuração
    ;   format("~nJogo iniciado! Tenho ~w palavra(s) candidata(s). Vamos la!~n", [N])
    ).

% ler_categoria(-Cat)
ler_categoria(Cat) :-
    format("Categoria [animal / fruta / pais]: "),
    ler_linha(Input),
    (   member(Input, [animal, animais]) -> Cat = animal
    ;   member(Input, [fruta,  frutas])  -> Cat = fruta
    ;   member(Input, [pais,   paises])  -> Cat = pais
    ;   format("[!] Categoria invalida. Use: animal, fruta ou pais.~n"),
        ler_categoria(Cat)
    ).

% ler_tamanho(-Tam)
ler_tamanho(Tam) :-
    format("Numero de letras da palavra: "),
    ler_linha(Input),
    (   atom_to_term(Input, Tam, _),
        integer(Tam),
        Tam > 0
    ->  true
    ;   format("[!] Digite um numero inteiro positivo.~n"),
        ler_tamanho(Tam)
    ).

% 
% Leitura de entrada do usuário
% 

% ler_linha(-Atom)
%   Lê uma linha do stdin, converte para minúsculas e retorna como átomo.
ler_linha(Atom) :-
    read_line_to_string(user_input, Line),
    (   Line = end_of_file
    ->  nl, format("Ate logo!~n"), halt(0)
    ;   atom_string(AtomRaw, Line),
        downcase_atom(AtomRaw, Atom)
    ).

% ler_posicoes(-Posicoes)
%   Lê uma linha e extrai inteiros positivos separados por espaço.
%   Exemplo: "2 4" → [2, 4]
ler_posicoes(Posicoes) :-
    read_line_to_string(user_input, Line),
    split_string(Line, " \t", " \t", Partes),
    include([P]>>(P \= ""), Partes, PartesLimpas),
    (   PartesLimpas = []
    ->  Posicoes = []
    ;   catch(
            maplist(string_para_inteiro_positivo, PartesLimpas, Posicoes),
            _,
            (   format("[!] Entrada invalida. Use numeros inteiros positivos separados por espaco.~n"),
                format("    Posicoes: "),
                ler_posicoes(Posicoes)
            )
        )
    ).

string_para_inteiro_positivo(S, N) :-
    number_string(N, S),
    integer(N),
    N > 0.

% 
% Exibição de estado


% exibir_estado/0 — mostra forca ASCII, padrão, vidas e letras tentadas
exibir_estado :-
    vidas(V),
    padrao(P),
    tentadas(T),
    candidatos(C),
    length(C, NC),
    nl,
    forca_ascii(V),
    nl,
    format("  Padrao  : "),
    exibir_padrao(P),
    format("  Vidas   : ~w/6  ~`*t~*|~n", [V, V]),   % barra visual simples
    format("  Tentadas: "),
    exibir_letras_tentadas(T),
    format("  Candidatos restantes: ~w palavra(s)~n", [NC]),
    nl.

% Exibe o padrão com espaços: g _ t _
exibir_padrao(Padrao) :-
    forall(member(Ch, Padrao), format("~w ", [Ch])),
    nl.

% Exibe letras tentadas separadas por vírgula, ou "(nenhuma)"
exibir_letras_tentadas([]) :-
    format("(nenhuma)~n").
exibir_letras_tentadas(Letras) :-
    Letras \= [],
    msort(Letras, Ord),            % ordem alfabética para melhorar leitura
    atomic_list_concat(Ord, ', ', Linha),
    format("~w~n", [Linha]).

% exibir_resultado(+Resultado)
exibir_resultado(ganhou(Palavra)) :-
    nl,
    format("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~n"),
    format("  ACERTEI! A palavra era: ~w~n", [Palavra]),
    format("  O Prolog venceu!~n"),
    format("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~n~n").

exibir_resultado(perdeu) :-
    nl,
    format("##################################################~n"),
    format("  FIM DE JOGO. As vidas acabaram.~n"),
    candidatos(Cands),
    (   Cands \= []
    ->  format("  Minhas melhores candidatas eram: ~w~n", [Cands])
    ;   format("  Nao restou nenhum candidato.~n")
    ),
    format("##################################################~n~n").

exibir_resultado(impossivel) :-
    nl,
    format("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!~n"),
    format("  CONTRADICAO detectada!~n"),
    format("  Nenhuma palavra e compativel com as respostas.~n"),
    format("  Verifique se as posicoes foram informadas corretamente.~n"),
    format("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!~n~n"),
    format("Deseja reiniciar a partida? [sim/nao]: "),
    ler_linha(Resp),
    (   Resp = sim
    ->  nova_partida
    ;   true
    ).


forca_ascii(Vidas) :-
    Erros is 6 - Vidas,
    arte_forca(Erros).

arte_forca(0) :-
    format("  +---+~n"),
    format("  |   |~n"),
    format("      |~n"),
    format("      |~n"),
    format("      |~n"),
    format("      |~n"),
    format("=========~n").
arte_forca(1) :-
    format("  +---+~n"),
    format("  |   |~n"),
    format("  O   |~n"),
    format("      |~n"),
    format("      |~n"),
    format("      |~n"),
    format("=========~n").
arte_forca(2) :-
    format("  +---+~n"),
    format("  |   |~n"),
    format("  O   |~n"),
    format("  |   |~n"),
    format("      |~n"),
    format("      |~n"),
    format("=========~n").
arte_forca(3) :-
    format("  +---+~n"),
    format("  |   |~n"),
    format("  O   |~n"),
    format(" /|   |~n"),
    format("      |~n"),
    format("      |~n"),
    format("=========~n").
arte_forca(4) :-
    format("  +---+~n"),
    format("  |   |~n"),
    format("  O   |~n"),
    format(" /|\\  |~n"),
    format("      |~n"),
    format("      |~n"),
    format("=========~n").
arte_forca(5) :-
    format("  +---+~n"),
    format("  |   |~n"),
    format("  O   |~n"),
    format(" /|\\  |~n"),
    format(" /    |~n"),
    format("      |~n"),
    format("=========~n").
arte_forca(6) :-
    format("  +---+~n"),
    format("  |   |~n"),
    format("  O   |~n"),
    format(" /|\\  |~n"),
    format(" / \\  |~n"),
    format("      |~n"),
    format("=========~n").


% Acessórios da interface


exibir_separador :-
    format("~n--------------------------------------------------~n").

banner :-
    nl,
    format("==================================================~n"),
    format("       HANGMAN SOLVER  --  Prolog Edition         ~n"),
    format("==================================================~n"),
    format("  Voce pensa na palavra e eu tento adivinhar.     ~n"),
    format("  Respondendo 'sim'/'nao' a cada letra sugerida.  ~n"),
    format("==================================================~n"),
    nl.

perguntar_jogar_novamente :-
    nl,
    format("Jogar novamente? [sim/nao]: "),
    ler_linha(Resp),
    (   Resp = sim
    ->  jogar
    ;   nl,
        format("Obrigado por jogar! ~n"),
        nl
    ).
