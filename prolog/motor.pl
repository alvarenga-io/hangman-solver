:- use_module(estado).

filtrar_candidatos(Letra,Posicoes) :-
    candidatos(Lista),
    include(compative(Letra,Posicoes), Lista, Nova),
    retract(candidatos(_)),
    assert(candidatos(Nova)).

compativel