
## Estrutura do Diretório

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
│   ├── estrategia.pl           % seleção de letra a tentar
│   ├── estado.pl                % estado dinâmico do jogo
│   └── server.pl               % servidor HTTP (SWI-Prolog http)
├── index.html                    % interface do jogador
├── estilo/
│   ├── style.css
│                  
├── js/
│    ├── app.js  % lógica de comunicação com o servidor
└── README.md
```