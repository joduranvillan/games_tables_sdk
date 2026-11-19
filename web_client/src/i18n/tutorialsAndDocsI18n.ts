import type { SupportedLocale } from "./index";
import type { GameTutorialSpec } from "../components/common/InteractiveTutorialPanel";
import type { DocumentationSection } from "../components/common/DocumentationCenterModal";

export interface LocalizedTutorialText {
  title: string;
  objective: string;
  steps: [string, string, string];
  tournamentRules: string;
}

export interface LocalizedTutorialUi {
  kicker: string;
  objectiveLabel: string;
  tournamentRulesLabel: string;
  executeTutorBtn: string;
  hideTutorialBtn: string;
  showTutorialBtn: string;
}

export const TUTORIAL_UI_BY_LOCALE: Record<SupportedLocale, LocalizedTutorialUi> = {
  es: {
    kicker: "GUÍA INTERACTIVA (14/14 JUEGOS CANÓNICOS)",
    objectiveLabel: "Objetivo:",
    tournamentRulesLabel: "Reglas de Torneo:",
    executeTutorBtn: "Ejecutar Jugada Sugerida por Tutor WASM",
    hideTutorialBtn: "Ocultar Tutorial Interactivo",
    showTutorialBtn: "Tutorial y Jugada Sugerida",
  },
  en: {
    kicker: "INTERACTIVE GUIDE (14/14 CANONICAL GAMES)",
    objectiveLabel: "Objective:",
    tournamentRulesLabel: "Tournament Rules:",
    executeTutorBtn: "Execute Move Suggested by WASM Tutor",
    hideTutorialBtn: "Hide Interactive Tutorial",
    showTutorialBtn: "Tutorial & Suggested Move",
  },
  pt: {
    kicker: "GUIA INTERATIVO (14/14 JOGOS CANÔNICOS)",
    objectiveLabel: "Objetivo:",
    tournamentRulesLabel: "Regras de Torneio:",
    executeTutorBtn: "Executar Jogada Sugerida pelo Tutor WASM",
    hideTutorialBtn: "Ocultar Tutorial Interativo",
    showTutorialBtn: "Tutorial e Jogada Sugerida",
  },
  it: {
    kicker: "GUIDA INTERATTIVA (14/14 GIOCHI CANONICI)",
    objectiveLabel: "Obiettivo:",
    tournamentRulesLabel: "Regole da Torneo:",
    executeTutorBtn: "Esegui Mossa Suggerita dal Tutor WASM",
    hideTutorialBtn: "Nascondi Tutorial Interattivo",
    showTutorialBtn: "Tutorial e Mossa Suggerita",
  },
  de: {
    kicker: "INTERAKTIVER LEITFADEN (14/14 KANONISCHE SPIELE)",
    objectiveLabel: "Ziel:",
    tournamentRulesLabel: "Turnierregeln:",
    executeTutorBtn: "Vom WASM-Tutor Empfohlenen Zug Ausführen",
    hideTutorialBtn: "Interaktives Tutorial Ausblenden",
    showTutorialBtn: "Tutorial & Zugvorschlag",
  },
  ja: {
    kicker: "インタラクティブガイド（全14公式ゲーム）",
    objectiveLabel: "勝利条件：",
    tournamentRulesLabel: "大会ルール：",
    executeTutorBtn: "WASMチューターの推奨手を実行",
    hideTutorialBtn: "インタラクティブガイドを隠す",
    showTutorialBtn: "チュートリアル＆AI推奨手",
  },
  fr: {
    kicker: "GUIDE INTERACTIF (14/14 JEUX CANONIQUES)",
    objectiveLabel: "Objectif :",
    tournamentRulesLabel: "Règles de Tournoi :",
    executeTutorBtn: "Jouer le Coup Suggéré par le Tuteur WASM",
    hideTutorialBtn: "Masquer le Tutoriel Interactif",
    showTutorialBtn: "Tutoriel et Coup Suggéré",
  },
  ko: {
    kicker: "인터랙티브 가이드 (14/14 공식 게임)",
    objectiveLabel: "목표:",
    tournamentRulesLabel: "토너먼트 규칙:",
    executeTutorBtn: "WASM 튜터 추천 수 실행",
    hideTutorialBtn: "인터랙티브 튜토리얼 숨기기",
    showTutorialBtn: "튜토리얼 및 추천 수",
  },
  zh: {
    kicker: "互动指南（14/14 标准游戏）",
    objectiveLabel: "目标：",
    tournamentRulesLabel: "锦标赛规则：",
    executeTutorBtn: "执行 WASM 导师推荐着法",
    hideTutorialBtn: "隐藏互动教程",
    showTutorialBtn: "教程与推荐着法",
  },
};

export const TUTORIALS_14_BY_LOCALE: Record<
  Exclude<SupportedLocale, "es">,
  Record<string, LocalizedTutorialText>
> = {
  en: {
    chess: {
      title: "FIDE Chess Tutorial",
      objective: "Checkmate the opponent's King or reach an official draw.",
      steps: [
        "1. Control the center of the board by advancing your central pawns (e2-e4 or d2-d4).",
        "2. Develop Knights and Bishops before moving the Queen, and castle to keep your King safe.",
        "3. Upon reaching the last rank, choose Queen, Rook, Bishop, or Knight in the FIDE promotion selector.",
      ],
      tournamentRules: "FIDE promotion to 4 pieces, check detection, castling, en passant, and draw offer/acceptance.",
    },
    checkers: {
      title: "Classic Checkers Tutorial",
      objective: "Capture all opponent checkers or block their legal moves.",
      steps: [
        "1. Advance diagonally across dark squares toward the opposite side.",
        "2. Whenever a diagonal capture is available, the mandatory capture rule activates automatically.",
        "3. Reaching the back row crowns your checker into a King (♛) able to move and jump forward and backward.",
      ],
      tournamentRules: "Mandatory capture, chained multi-jumps, and King crowning.",
    },
    uno: {
      title: "UNO Tutorial",
      objective: "Be the first player to empty your hand of cards.",
      steps: [
        "1. Play a card matching the color or value of the top discard pile card, or play a Wild card.",
        "2. When a draw penalty (+2 or +4) is active, stack another draw card or draw the accumulated penalty.",
        "3. Press the UNO! button when down to 1 or 2 cards to protect yourself from penalties.",
      ],
      tournamentRules: "108-card deck, wild color selector, stacking penalties, and UNO! call.",
    },
    goose: {
      title: "Game of the Goose Tutorial",
      objective: "Land on the Garden of the Goose (square 63) with an exact dice roll.",
      steps: [
        "1. Roll the two 3D dice to advance along the 63-square spiral track.",
        "2. Landing on a Goose (5, 9, 14, 18, 23, 27...) or Bridge (6, 12) jumps forward and grants an extra roll.",
        "3. Avoid the Well (31), Maze (42), Jail (52), and Skull (58). Overshooting 63 bounces backward.",
      ],
      tournamentRules: "13 Geese, Bridges, Inn, Well, Maze, Jail, Skull, and exact bounce at 63.",
    },
    go: {
      title: "Go (Weiqi / Baduk) Tutorial",
      objective: "Control more territory intersections and captures than your opponent at game end.",
      steps: [
        "1. Place stones on empty intersections, prioritizing star points (Hoshi) and corners.",
        "2. Completely surround all orthogonal liberties of opponent stone chains to capture them.",
        "3. After 2 consecutive passes, mark dead stones (✕) and confirm the final score with 6.5 Komi.",
      ],
      tournamentRules: "Hoshi handicap, BFS chain capture, suicide prohibition, Ko rule, and 6.5 Komi.",
    },
    shogi: {
      title: "Shogi Tutorial",
      objective: "Capture the opponent's King while re-dropping captured pieces from your Komadai tray.",
      steps: [
        "1. Advance your pawn line to open the Bishop (角) diagonal and Rook (飛) file.",
        "2. Captured pieces move to your Komadai stand and can be dropped onto any legal empty square.",
        "3. Entering the last 3 enemy ranks allows piece promotion according to FESA rules.",
      ],
      tournamentRules: "Komadai piece drops, Nifu (double pawn) ban, Uchifuzume ban, and FESA promotion.",
    },
    xiangqi: {
      title: "Xiangqi (Chinese Chess) Tutorial",
      objective: "Checkmate or capture the enemy General inside their 3×3 Palace.",
      steps: [
        "1. Deploy your Chariots (車) and Horses (馬), watching out for adjacent leg-blocking squares.",
        "2. Fire your Cannons (炮) by jumping over exactly one screen piece to capture at a distance.",
        "3. Remember the Flying General rule: the two Generals may never face each other on an open file.",
      ],
      tournamentRules: "Chu He / Han Jie River, 3×3 Palaces, Cannon screen jump, and Flying General ban.",
    },
    chinese_checkers: {
      title: "Chinese Checkers (Sternhalma) Tutorial",
      objective: "Move all 10 of your marbles into the opposite point of the 6-pointed star.",
      steps: [
        "1. Select a marble of your color and move it to an adjacent empty hole.",
        "2. Build marble ladders to chain long multi-hop jumps across the center of the star.",
        "3. Marbles are never captured; use both your own and your opponent's marbles as jumping bridges.",
      ],
      tournamentRules: "121-hole hexagonal star with single steps and chained multi-jumps.",
    },
    backgammon: {
      title: "Backgammon Tutorial",
      objective: "Bring all 15 checkers into your home board and bear them off.",
      steps: [
        "1. Roll the 3D dice and advance your checkers along the 24 points.",
        "2. Hit solitary opponent checkers (Blots) to send them to the Center Bar.",
        "3. When holding a strong positional edge, offer to raise the stakes with the Doubling Cube (×2, ×4, ×8).",
      ],
      tournamentRules: "24 points, Center Bar re-entry, Bear-Off, double rolls, and Doubling Cube.",
    },
    ludo: {
      title: "Ludo Tutorial",
      objective: "Guide all 4 of your tokens through the 57-step circuit into the central goal.",
      steps: [
        "1. Roll a 6 to deploy a token from your corner yard onto the starting square.",
        "2. The 8 star squares (★) are safe havens where your tokens cannot be captured.",
        "3. Rolling a 6, capturing an enemy token, or reaching the goal grants an immediate bonus roll.",
      ],
      tournamentRules: "52-square outer track + 5 home lane squares, 8 safe stars, and exact roll into goal 57.",
    },
    battleship: {
      title: "Battleship Tutorial",
      objective: "Sink all 5 warships of the enemy fleet (17 total hits).",
      steps: [
        "1. Click any coordinate on the 10×10 Enemy Attack Radar to fire a torpedo.",
        "2. When you score a hit (💥), target adjacent orthogonal squares to finish sinking the ship.",
        "3. Enable the Salvo Rule if you want to keep firing after every successful hit.",
      ],
      tournamentRules: "5-ship fleet (lengths 5, 4, 3, 3, 2), optional Salvo streak rule, and rematch.",
    },
    mille_bornes: {
      title: "Mille Bornes (1000 Miles) Tutorial",
      objective: "Reach exactly 1000 km on your odometer before your opponent.",
      steps: [
        "1. Play Distance cards (50, 75, 100, 200 km) whenever you have a Green Light (Clear Road).",
        "2. Deploy the 4 Safety shields (Right of Way, Extra Tank, Puncture Proof, Driving Ace) for permanent immunity.",
        "3. Trigger ⚡ Coup Fourré! against an incoming hazard for +100 km bonus and an extra turn.",
      ],
      tournamentRules: "1000 km route, 4 Safety shields, Hazard/Remedy cards, and Coup Fourré! reaction.",
    },
    monopoly: {
      title: "Monopoly Tutorial",
      objective: "Build real-estate monopolies and grow your wealth through property rents.",
      steps: [
        "1. Roll the 3D dice to travel around the 40 board spaces and collect $200 whenever you pass GO.",
        "2. Buy unowned properties you land on and build houses/hotels evenly across color groups.",
        "3. If you need immediate cash, mortgage properties by selecting them on the board.",
      ],
      tournamentRules: "40 spaces, property purchases, auctions, even house/hotel building, and mortgages.",
    },
    crisis: {
      title: "Crisis / Risk Tutorial",
      objective: "Conquer territories across all 6 continents and dominate the global map.",
      steps: [
        "1. During the Reinforcement Phase (PlaceArmies), click your territories to deploy new armies.",
        "2. During the Attack Phase, select an owned territory with 2+ armies and attack an adjacent enemy territory.",
        "3. Once you collect 3 conquest cards, trade them in for +6 bonus armies.",
      ],
      tournamentRules: "30 territories across 6 continents, reinforcements, 3v3 dice combat, and card trades.",
    },
  },
  pt: {
    chess: {
      title: "Tutorial de Xadrez FIDE",
      objective: "Dar xeque-mate ao Rei adversário ou acordar empate regulamentar.",
      steps: [
        "1. Controle o centro do tabuleiro avançando seus peões centrais (e2-e4 ou d2-d4).",
        "2. Desenvolva cavalos e bispos antes de mover a Dama e faça o roque para proteger seu Rei.",
        "3. Ao chegar à última fileira, escolha entre Dama, Torre, Bispo ou Cavalo no seletor FIDE.",
      ],
      tournamentRules: "Promoção FIDE para 4 peças, detecção de xeque, roque, en passant e oferta de empate.",
    },
    checkers: {
      title: "Tutorial de Damas Clássicas",
      objective: "Capturar todas as peças do oponente ou bloquear seus movimentos.",
      steps: [
        "1. Avance na diagonal pelas casas escuras em direção ao lado oposto.",
        "2. Se houver uma captura diagonal disponível, a regra de captura obrigatória é ativada automaticamente.",
        "3. Ao alcançar a última fileira, sua peça é coroada Dama (♛) e pode mover para frente e para trás.",
      ],
      tournamentRules: "Captura obrigatória, saltos múltiplos encadeados e coroação de Dama.",
    },
    uno: {
      title: "Tutorial de UNO",
      objective: "Ser o primeiro jogador a ficar sem cartas na mão.",
      steps: [
        "1. Jogue uma carta que combine em cor ou valor com o topo do descarte, ou use um Curinga.",
        "2. Se houver penalidade ativa (+2 ou +4), empilhe outra carta de compra ou compre a penalidade acumulada.",
        "3. Aperte o botão ¡UNO! quando restarem 1 ou 2 cartas para evitar penalidades.",
      ],
      tournamentRules: "Baralho de 108 cartas, seletor de cor em curingas e grito ¡UNO!.",
    },
    goose: {
      title: "Tutorial do Jogo da Gansa",
      objective: "Chegar com rolagem exata ao Jardim da Gansa (casa 63).",
      steps: [
        "1. Lance os dois dados 3D para avançar pela espiral de 63 casas.",
        "2. Se cair em uma Gansa (5, 9, 14, 18, 23, 27...) ou Ponte (6, 12), salte e jogue novamente.",
        "3. Evite o Poço (31), o Labirinto (42), a Prisão (52) e a Caveira (58). Se passar de 63, recua.",
      ],
      tournamentRules: "13 Gansas, Pontes, Pousada, Poço, Labirinto, Prisão, Caveira e recuo exato na 63.",
    },
    go: {
      title: "Tutorial de Go (Weiqi / Baduk)",
      objective: "Controlar mais interseções e capturas que o adversário ao final da partida.",
      steps: [
        "1. Coloque pedras nas interseções vazias priorizando os pontos estrela (Hoshi).",
        "2. Cerque completamente as liberdades ortogonais das cadeias adversárias para capturá-las.",
        "3. Após 2 passes consecutivos, marque as pedras mortas (✕) e confirme a contagem com Komi 6.5.",
      ],
      tournamentRules: "Handicap em pontos Hoshi, captura BFS, proibição de suicídio, regra de Ko e Komi 6.5.",
    },
    shogi: {
      title: "Tutorial de Shogi",
      objective: "Capturar o Rei adversário reutilizando as peças capturadas do seu Komadai.",
      steps: [
        "1. Avance sua linha de peões para abrir a diagonal do Bispo (角) e a coluna da Torre (飛).",
        "2. As peças capturadas vão para sua bandeja Komadai e podem ser reintroduzidas em qualquer casa vazia.",
        "3. Ao entrar nas 3 últimas fileiras inimigas, promova suas peças segundo o regulamento FESA.",
      ],
      tournamentRules: "Reentrada desde o Komadai, proibição de peão duplo (Nifu) e promoção FESA.",
    },
    xiangqi: {
      title: "Tutorial de Xiangqi (Xadrez Chinês)",
      objective: "Capturar ou dar mate ao General inimigo dentro do seu Palácio 3×3.",
      steps: [
        "1. Posicione seus Carros (車) e Cavalos (馬) cuidando para que os Cavalos não tenham o passo bloqueado.",
        "2. Use seus Canhões (炮) saltando sobre uma peça de tela para capturar à distância.",
        "3. Lembre-se de que os dois Generais nunca podem se enfrentar diretamente em uma coluna aberta.",
      ],
      tournamentRules: "Rio Chu He / Han Jie, Palácios 3×3, Canhão com tela e General Voador.",
    },
    chinese_checkers: {
      title: "Tutorial de Damas Chinesas",
      objective: "Levar todas as suas 10 bolinhas ao triângulo oposto da estrela hexagonal.",
      steps: [
        "1. Selecione uma bolinha da sua cor e mova-a para uma casa vazia adjacente.",
        "2. Construa escadas de bolinhas para encadear saltos longos de ponta a ponta.",
        "3. As bolinhas nunca são capturadas; use tanto suas peças quanto as do rival como ponte.",
      ],
      tournamentRules: "Estrela hexagonal de 121 casas com saltos múltiplos em cadeia.",
    },
    backgammon: {
      title: "Tutorial de Gamão (Backgammon)",
      objective: "Levar suas 15 fichas ao seu quadrante interno e retirá-las (Bear-Off).",
      steps: [
        "1. Lance os dados 3D e avance suas fichas pelos 24 picos.",
        "2. Golpeie fichas solitárias rivais (Blots) para enviá-las à Barra Central.",
        "3. Se tiver vantagem posicional, ofereça dobrar a aposta com o Cubo de Dobra (×2, ×4, ×8).",
      ],
      tournamentRules: "24 picos, Barra Central, Bear-Off e Cubo de Dobra.",
    },
    ludo: {
      title: "Tutorial de Ludo",
      objective: "Completar o circuito de 57 passos com suas 4 fichas até a meta central.",
      steps: [
        "1. Escolha qual das suas 4 fichas deseja mover e lance os dados 3D.",
        "2. As 8 casas com estrela (★) são refúgios seguros onde suas fichas não podem ser capturadas.",
        "3. Tirar um 6 ou levar uma ficha à meta concede uma jogada extra imediata.",
      ],
      tournamentRules: "52 casas + 5 do corredor de meta, 8 estrelas seguras e jogada extra com 6.",
    },
    battleship: {
      title: "Tutorial de Batalha Naval",
      objective: "Afundar os 5 navios da frota inimiga (17 impactos no total).",
      steps: [
        "1. Clique em qualquer coordenada do radar inimigo 10×10 para disparar um torpedo.",
        "2. Ao conseguir um impacto (💥), explore as casas ortogonais adjacentes para afundar o navio.",
        "3. Ative a Regra de Rajada se desejar manter o turno após cada impacto.",
      ],
      tournamentRules: "Frota de 5 navios (5, 4, 3, 3, 2), regra de rajada opcional e revanche.",
    },
    mille_bornes: {
      title: "Tutorial de Mil Milhas (Mille Bornes)",
      objective: "Alcançar exatamente 1000 km no seu hodômetro antes do seu rival.",
      steps: [
        "1. Jogue cartas de Distância (50, 75, 100, 200 km) enquanto tiver Via Livre.",
        "2. Implante os 4 Escudos (Prioridade, Cisterna, Imfurável, Ás do Volante) para se imunizar.",
        "3. Use o botão ⚡ Coup Fourré! diante de um ataque para somar +100 km de bônus e turno extra.",
      ],
      tournamentRules: "Rota de 1000 km, 4 cartas de segurança (Safeties) e reação Coup Fourré!.",
    },
    monopoly: {
      title: "Tutorial de Monopoly",
      objective: "Construir monopólios imobiliários e multiplicar seu capital mediante aluguéis.",
      steps: [
        "1. Lance os dados 3D para percorrer as 40 casas do tabuleiro e receber $200 ao passar por GO.",
        "2. Compre as propriedades livres em que cair e construa casas/hotéis de forma uniforme.",
        "3. Se precisar de liquidez imediata, hipoteque propriedades selecionando-as no tabuleiro.",
      ],
      tournamentRules: "40 casas, compra de propriedades, construção uniforme de casas/hotéis e hipotecas.",
    },
    crisis: {
      title: "Tutorial de Crisis / War",
      objective: "Conquistar territórios através dos 6 continentes e dominar o mapa global.",
      steps: [
        "1. Na Fase de Reforço (PlaceArmies), clique nos seus territórios para posicionar exércitos.",
        "2. Na Fase de Ataque, selecione um território próprio com 2+ exércitos e ataque um inimigo adjacente.",
        "3. Ao reunir 3 cartas de território conquistado, troque-as por +6 exércitos adicionais.",
      ],
      tournamentRules: "30 territórios em 6 continentes, reforços, combate 3v3 e troca de cartas.",
    },
  },
  it: {
    chess: {
      title: "Tutorial di Scacchi FIDE",
      objective: "Dare scacco matto al Re avversario o concordare una patta regolamentare.",
      steps: [
        "1. Controlla il centro della scacchiera avanzando i pedoni centrali (e2-e4 o d2-d4).",
        "2. Sviluppa cavalli e alfieri prima di muovere la Donna e arrocca per mettere al sicuro il Re.",
        "3. Raggiunta l'ultima traversa, scegli tra Donna, Torre, Alfiere o Cavallo nel selettore FIDE.",
      ],
      tournamentRules: "Promozione FIDE a 4 pezzi, rilevamento scacco, arrocco, en passant e offerta di patta.",
    },
    checkers: {
      title: "Tutorial di Dama Classica",
      objective: "Catturare tutte le pedine avversarie o bloccarne i movimenti.",
      steps: [
        "1. Avanza in diagonale sulle caselle scure verso il lato opposto.",
        "2. Se è disponibile una presa diagonale, la regola della presa obbligatoria si attiva automaticamente.",
        "3. Raggiunta l'ultima riga, la pedina diventa Dama (♛) e può muovere avanti e indietro.",
      ],
      tournamentRules: "Presa obbligatoria, salti multipli concatenati e promozione a Dama.",
    },
    uno: {
      title: "Tutorial di UNO",
      objective: "Essere il primo giocatore a rimanere senza carte in mano.",
      steps: [
        "1. Gioca una carta che corrisponda per colore o valore agli scarti, oppure usa un Jolly.",
        "2. Se c'è una penalità attiva (+2 o +4), impila un'altra carta pesca o pesca la penalità accumulata.",
        "3. Premi il pulsante ¡UNO! quando ti restano 1 o 2 carte per evitare sanzioni.",
      ],
      tournamentRules: "Mazzo da 108 carte, selettore colore sui jolly e chiamata ¡UNO!.",
    },
    goose: {
      title: "Tutorial del Gioco dell'Oca",
      objective: "Arrivare con un lancio esatto al Giardino dell'Oca (casella 63).",
      steps: [
        "1. Lancia i due dadi 3D per avanzare lungo la spirale di 63 caselle.",
        "2. Se cadi su un'Oca (5, 9, 14, 18, 23, 27...) o un Ponte (6, 12), salti in avanti e tiri di nuovo.",
        "3. Evita il Pozzo (31), il Labirinto (42), la Prigione (52) e il Teschio (58). Se superi 63, rimbalzi.",
      ],
      tournamentRules: "13 Oche, Ponti, Locanda, Pozzo, Labirinto, Prigione, Teschio e rimbalzo esatto alla 63.",
    },
    go: {
      title: "Tutorial di Go (Weiqi / Baduk)",
      objective: "Controllare più intersezioni e catture dell'avversario a fine partita.",
      steps: [
        "1. Posiziona le pietre sulle intersezioni libere dando priorità ai punti stella (Hoshi).",
        "2. Circonda completamente le libertà ortogonali delle catene avversarie per catturarle.",
        "3. Dopo 2 passi consecutivi, segna le pietre morte (✕) e conferma il punteggio con Komi 6.5.",
      ],
      tournamentRules: "Handicap sui punti Hoshi, cattura BFS, divieto di suicidio, regola del Ko e Komi 6.5.",
    },
    shogi: {
      title: "Tutorial di Shogi",
      objective: "Catturare il Re avversario riutilizzando i pezzi catturati dal tuo Komadai.",
      steps: [
        "1. Avanza la linea dei pedoni per aprire la diagonale dell'Alfiere (角) e la colonna della Torre (飛).",
        "2. I pezzi catturati vanno sul vassoio Komadai e possono essere paracadutati su qualsiasi casella vuota.",
        "3. Entrando nelle ultime 3 traverse nemiche, promuovi i pezzi secondo il regolamento FESA.",
      ],
      tournamentRules: "Reinserimento dal Komadai, divieto di doppio pedone (Nifu) e promozione FESA.",
    },
    xiangqi: {
      title: "Tutorial di Xiangqi (Scacchi Cinesi)",
      objective: "Catturare o dare matto al Generale nemico dentro il suo Palazzo 3×3.",
      steps: [
        "1. Schiera Carri (車) e Cavalli (馬) facendo attenzione che i Cavalli non abbiano il passo bloccato.",
        "2. Usa i Cannoni (炮) saltando sopra un pezzo schermo per catturare a distanza.",
        "3. Ricorda che i due Generali non possono mai guardarsi direttamente su una colonna aperta.",
      ],
      tournamentRules: "Fiume Chu He / Han Jie, Palazzi 3×3, Cannone con schermo e Generale Volante.",
    },
    chinese_checkers: {
      title: "Tutorial di Dama Cinese",
      objective: "Portare tutte le tue 10 biglie nel triangolo opposto della stella esagonale.",
      steps: [
        "1. Seleziona una biglia del tuo colore e muovila in una casella vuota adiacente.",
        "2. Costruisci scale di biglie per concatenare lunghi salti da un estremo all'altro.",
        "3. Le biglie non vengono mai catturate; usa sia i tuoi pezzi sia quelli avversari come ponte.",
      ],
      tournamentRules: "Stella esagonale da 121 caselle con salti multipli a catena.",
    },
    backgammon: {
      title: "Tutorial di Backgammon",
      objective: "Portare le tue 15 pedine nel quadrante interno e rimuoverle (Bear-Off).",
      steps: [
        "1. Lancia i dadi 3D e avanza le pedine lungo le 24 punte.",
        "2. Colpisci le pedine solitarie avversarie (Blot) per mandarle sulla Barra Centrale.",
        "3. Se hai vantaggio posizionale, offri il raddoppio con il Cubo del Raddoppio (×2, ×4, ×8).",
      ],
      tournamentRules: "24 punte, Barra Centrale, Bear-Off e Cubo del Raddoppio.",
    },
    ludo: {
      title: "Tutorial di Ludo",
      objective: "Completare il circuito di 57 passi con le tue 4 pedine fino al traguardo centrale.",
      steps: [
        "1. Scegli quale delle tue 4 pedine muovere e lancia i dadi 3D.",
        "2. Le 8 caselle con stella (★) sono rifugi sicuri dove le tue pedine non possono essere catturate.",
        "3. Ottenere un 6 o portare una pedina al traguardo assegna un tiro extra immediato.",
      ],
      tournamentRules: "52 caselle + 5 di corridoio finale, 8 stelle sicure e tiro extra con 6.",
    },
    battleship: {
      title: "Tutorial di Battaglia Navale",
      objective: "Affondare le 5 navi della flotta nemica (17 colpi a segno in totale).",
      steps: [
        "1. Clicca su qualsiasi coordinata del radar nemico 10×10 per lanciare un siluro.",
        "2. Quando ottieni un colpo a segno (💥), esplora le caselle ortogonali adiacenti per affondare la nave.",
        "3. Attiva la Regola Raffica se desideri conservare il turno dopo ogni impatto.",
      ],
      tournamentRules: "Flotta di 5 navi (5, 4, 3, 3, 2), regola raffica opzionale e rivincita.",
    },
    mille_bornes: {
      title: "Tutorial di Mille Miglia (Mille Bornes)",
      objective: "Raggiungere esattamente 1000 km sul contachilometri prima dell'avversario.",
      steps: [
        "1. Gioca carte Distanza (50, 75, 100, 200 km) finché hai Via Libera (Semaforo Verde).",
        "2. Schiera i 4 Scudi (Priorità, Cisterna, Antiforatura, Asso del Volante) per renderti immune.",
        "3. Usa il pulsante ⚡ Coup Fourré! contro un attacco per ottenere +100 km bonus e turno extra.",
      ],
      tournamentRules: "Percorso di 1000 km, 4 carte sicurezza (Safeties) e reazione Coup Fourré!.",
    },
    monopoly: {
      title: "Tutorial di Monopoly",
      objective: "Costruire monopoli immobiliari e moltiplicare il capitale tramite gli affitti.",
      steps: [
        "1. Lancia i dadi 3D per percorrere le 40 caselle del tabellone e incassare $200 passando dal VIA.",
        "2. Acquista le proprietà libere su cui atterri e costruisci case/hotel in modo uniforme.",
        "3. Se hai bisogno di liquidità immediata, ipoteca le proprietà selezionandole sul tabellone.",
      ],
      tournamentRules: "40 caselle, acquisto proprietà, costruzione uniforme di case/hotel e ipoteche.",
    },
    crisis: {
      title: "Tutorial di Crisis / Risiko",
      objective: "Conquistare territori attraverso i 6 continenti e dominare la mappa globale.",
      steps: [
        "1. Nella Fase di Rinforzo (PlaceArmies), clicca sui tuoi territori per schierare armate.",
        "2. Nella Fase di Attacco, seleziona un tuo territorio con 2+ armate e attacca un nemico adiacente.",
        "3. Raccolte 3 carte territorio conquistato, scambiale per +6 armate aggiuntive.",
      ],
      tournamentRules: "30 territori in 6 continenti, rinforzi, combattimento 3v3 e scambio carte.",
    },
  },
  de: {
    chess: {
      title: "FIDE-Schach-Tutorial",
      objective: "Setze den gegnerischen König schachmatt oder erziele ein reguläres Remis.",
      steps: [
        "1. Kontrolliere das Brettzentrum durch Vorrücken deiner Zentralbauern (e2-e4 oder d2-d4).",
        "2. Entwickle Springer und Läufer vor der Dame und rochiere, um deinen König zu schützen.",
        "3. Wähle auf der Grundreihe im FIDE-Auswahlmenü zwischen Dame, Turm, Läufer oder Springer.",
      ],
      tournamentRules: "FIDE-Umwandlung in 4 Figuren, Schacherkennung, Rochade, En Passant und Remisangebot.",
    },
    checkers: {
      title: "Klassisches Dame-Tutorial",
      objective: "Schlage alle gegnerischen Steine oder blockiere ihre gültigen Züge.",
      steps: [
        "1. Ziehe diagonal über die dunklen Felder auf die gegenüberliegende Seite.",
        "2. Sobald ein diagonaler Schlagzug möglich ist, greift automatisch der Schlagzwang.",
        "3. Auf der Grundreihe wird dein Stein zur Dame (♛) gekrönt und zieht vorwärts wie rückwärts.",
      ],
      tournamentRules: "Schlagzwang, verkettete Mehrfachsprünge und Damenkrönung.",
    },
    uno: {
      title: "UNO-Tutorial",
      objective: "Leere als erster Spieler vollständig deine Kartenhand.",
      steps: [
        "1. Spiele eine Karte gleicher Farbe oder gleichen Werts wie auf dem Ablagestapel oder nutze einen Joker.",
        "2. Bei aktiver Strafkarte (+2 oder +4) lege eine weitere Ziehkarte darauf oder ziehe die Strafe.",
        "3. Drücke bei 1 oder 2 verbleibenden Karten den ¡UNO!-Button, um Strafkarten zu vermeiden.",
      ],
      tournamentRules: "108-Karten-Deck, Farbwahl bei Jokern und ¡UNO!-Ruf.",
    },
    goose: {
      title: "Gänsespiel-Tutorial",
      objective: "Erreiche mit exaktem Würfelwurf den Gänsegarten (Feld 63).",
      steps: [
        "1. Wirf die beiden 3D-Würfel, um auf der 63-Felder-Spirale voranzurücken.",
        "2. Auf einer Gans (5, 9, 14, 18, 23, 27...) oder Brücke (6, 12) springst du weiter und würfelst erneut.",
        "3. Meide Brunnen (31), Labyrinth (42), Gefängnis (52) und Totenkopf (58). Über 63 hinaus prallst du zurück.",
      ],
      tournamentRules: "13 Gänse, Brücken, Herberge, Brunnen, Labyrinth, Gefängnis, Totenkopf und exakter Rückprall.",
    },
    go: {
      title: "Go (Weiqi / Baduk) Tutorial",
      objective: "Kontrolliere am Spielende mehr Schnittpunkte und Gefangene als dein Gegner.",
      steps: [
        "1. Setze Steine auf freie Schnittpunkte und bevorzuge anfangs die Sternpunkte (Hoshi).",
        "2. Umschließe alle orthogonalen Freiheiten gegnerischer Steinketten, um sie zu fangen.",
        "3. Markiere nach 2 aufeinanderfolgenden Pässen tote Steine (✕) und bestätige die Zählung mit 6.5 Komi.",
      ],
      tournamentRules: "Hoshi-Handicap, BFS-Kettenfang, Selbstmordverbot, Ko-Regel und 6.5 Komi.",
    },
    shogi: {
      title: "Shogi-Tutorial",
      objective: "Schlage den gegnerischen König und setze gefangene Figuren von deinem Komadai wieder ein.",
      steps: [
        "1. Rücke deine Bauernlinie vor, um die Läuferdiagonale (角) und Turmlinie (飛) zu öffnen.",
        "2. Gefangene Figuren landen auf deinem Komadai und können auf freie Felder eingesetzt werden.",
        "3. In den letzten 3 gegnerischen Reihen kannst du Figuren nach FESA-Regeln befördern.",
      ],
      tournamentRules: "Komadai-Figureneinsatz, Nifu-Verbot (Doppelbauer) und FESA-Beförderung.",
    },
    xiangqi: {
      title: "Xiangqi (Chinesisches Schach) Tutorial",
      objective: "Setze den feindlichen General innerhalb seines 3×3-Palastes matt.",
      steps: [
        "1. Entwickle Streitwagen (車) und Pferde (馬) und achte auf blockierte Pferdebeine.",
        "2. Nutze deine Kanonen (炮), indem du über genau einen Schirmstein springst, um aus der Distanz zu schlagen.",
        "3. Beachte die Regel des Fliegenden Generals: Beide Generäle dürfen sich nie offen gegenüberstehen.",
      ],
      tournamentRules: "Chu-He/Han-Jie-Fluss, 3×3-Paläste, Kanonensprung mit Schirm und Fliegender General.",
    },
    chinese_checkers: {
      title: "Halma / Sternhalma-Tutorial",
      objective: "Bringe alle 10 eigenen Murmeln in die gegenüberliegende Spitze des sechszackigen Sterns.",
      steps: [
        "1. Wähle eine Murmel deiner Farbe und ziehe auf ein benachbartes freies Feld.",
        "2. Baue Murmel-Leitern auf, um weite Kettensprünge über das Sternzentrum auszuführen.",
        "3. Murmeln werden niemals geschlagen; nutze eigene wie gegnerische Steine als Sprungbrücken.",
      ],
      tournamentRules: "121-Felder-Sternbrett mit Einzelschritten und verketteten Mehrfachsprüngen.",
    },
    backgammon: {
      title: "Backgammon-Tutorial",
      objective: "Führe alle 15 Steine in dein Heimfeld und würfle sie heraus (Bear-Off).",
      steps: [
        "1. Wirf die 3D-Würfel und ziehe deine Steine über die 24 Zungen.",
        "2. Schlage einzeln stehende gegnerische Steine (Blots), um sie auf die Mittelbar zu schicken.",
        "3. Biete bei klarem Stellungsvorteil eine Verdopplung mit dem Verdopplungswürfel (×2, ×4, ×8) an.",
      ],
      tournamentRules: "24 Zungen, Mittelbar, Bear-Off, Pasch-Würfe und Verdopplungswürfel.",
    },
    ludo: {
      title: "Ludo-Tutorial",
      objective: "Führe alle 4 Spielfiguren über den 57-Schritte-Rundkurs ins zentrale Ziel.",
      steps: [
        "1. Wähle eine deiner 4 Figuren und wirf die 3D-Würfel (eine 6 bringt eine Figur aus der Basis).",
        "2. Die 8 Sternfelder (★) sind sichere Schutzfelder, auf denen Figuren nicht geschlagen werden können.",
        "3. Eine 6, ein Schlagzug oder das Erreichen des Ziels gewährt sofort einen Bonuswurf.",
      ],
      tournamentRules: "52 Außenfelder + 5 Zielfelder, 8 sichere Sterne und Extrawurf bei 6.",
    },
    battleship: {
      title: "Schiffe-Versenken-Tutorial",
      objective: "Versenke alle 5 Kriegsschiffe der feindlichen Flotte (insgesamt 17 Treffer).",
      steps: [
        "1. Klicke auf eine Koordinate im 10×10-Angriffsradar, um einen Torpedo abzufeuern.",
        "2. Untersuche nach einem Treffer (💥) die orthogonal angrenzenden Felder, um das Schiff zu versenken.",
        "3. Aktiviere die Salven-Regel, wenn du nach jedem Treffer weiterfeuern möchtest.",
      ],
      tournamentRules: "5-Schiffe-Flotte (5, 4, 3, 3, 2), optionale Salven-Regel und Revanche.",
    },
    mille_bornes: {
      title: "Mille-Bornes-Tutorial (1000 Meilen)",
      objective: "Erreiche auf deinem Tachometer exakt 1000 km vor deinem Gegner.",
      steps: [
        "1. Spiele Distanzkarten (50, 75, 100, 200 km), solange du Freie Fahrt (Grünes Licht) hast.",
        "2. Spiele die 4 Schutzschilde (Vorfahrt, Zusatztank, Pannensicher, Meisterfahrer) für dauerhafte Immunität.",
        "3. Nutze ⚡ Coup Fourré! gegen einen Angriff für +100 km Bonus und einen Extrazug.",
      ],
      tournamentRules: "1000-km-Strecke, 4 Sicherheitskarten (Safeties) und Coup-Fourré!-Reaktion.",
    },
    monopoly: {
      title: "Monopoly-Tutorial",
      objective: "Baue Immobilien-Monopole auf und vermehre dein Kapital durch Mieteinnahmen.",
      steps: [
        "1. Wirf die 3D-Würfel, ziehe über die 40 Felder und kassiere 200 $ beim Passieren von LOS.",
        "2. Kaufe freie Grundstücke, auf denen du landest, und baue Häuser/Hotels gleichmäßig auf.",
        "3. Wenn du sofort Bargeld benötigst, nimm Hypotheken auf deine Grundstücke auf.",
      ],
      tournamentRules: "40 Felder, Grundstückskauf, gleichmäßiger Haus-/Hotelbau und Hypotheken.",
    },
    crisis: {
      title: "Crisis / Risiko-Tutorial",
      objective: "Erobere Gebiete auf allen 6 Kontinenten und beherrsche die Weltkarte.",
      steps: [
        "1. Klicke in der Verstärkungsphase (PlaceArmies) auf deine Gebiete, um neue Armeen zu platzieren.",
        "2. Wähle in der Angriffsphase ein eigenes Gebiet mit 2+ Armeen und greife ein Nachbargebiet an.",
        "3. Tausche 3 gesammelte Gebietskarten gegen +6 zusätzliche Bonusarmeen ein.",
      ],
      tournamentRules: "30 Gebiete auf 6 Kontinenten, Verstärkungen, 3v3-Würfelkampf und Kartentausch.",
    },
  },
  ja: {
    chess: {
      title: "FIDE チェス チュートリアル",
      objective: "相手のキングをチェックメイトするか、公式ルールに基づく引き分け（ドロー）を目指します。",
      steps: [
        "1. 中央のポーン（e2-e4 または d2-d4）を進めて盤面中央を制圧しましょう。",
        "2. クイーンを動かす前にナイトとビショップを展開し、キャスリングでキングを安全に守ります。",
        "3. 最終段に到達したら、FIDEプロモーション選択でクイーン・ルーク・ビショップ・ナイトから選びます。",
      ],
      tournamentRules: "FIDE 4駒種プロモーション、チェック判定、キャスリング、アンパッサン、ドロー提案・合意。",
    },
    checkers: {
      title: "クラシック・チェッカー チュートリアル",
      objective: "相手の駒をすべて捕獲するか、合法手を完全に封じ込めます。",
      steps: [
        "1. 黒マスを斜め前方へ進み、相手陣地の最終列を目指します。",
        "2. 飛び越えて取れる駒がある場合、強制捕獲ルールが自動的に適用されます。",
        "3. 最終列に到達するとキング（♛）に昇格し、前後両方向へ移動・連続ジャンプが可能になります。",
      ],
      tournamentRules: "強制捕獲ルール、連続マルチジャンプ、キングへの昇格。",
    },
    uno: {
      title: "UNO チュートリアル",
      objective: "手札のカードを誰よりも早くすべて出し切ります。",
      steps: [
        "1. 捨て札の一番上と同じ色・数字・記号のカードを出すか、ワイルドカードを使用します。",
        "2. ドロー累積（+2 または +4）が発生している場合は、同じカードを重ねるか累積枚数を引きます。",
        "3. 手札が残り1〜2枚になったら「¡UNO!」ボタンを押してペナルティを防ぎましょう。",
      ],
      tournamentRules: "108枚デッキ、ワイルド色選択、ペナルティ累積、UNOコール。",
    },
    goose: {
      title: "ガチョウのゲーム チュートリアル",
      objective: "サイコロの正確な出目で63マス目の「ガチョウの庭園」にぴったり止まります。",
      steps: [
        "1. 2つの3Dダイスを振って63マスの螺旋トラックを進みます。",
        "2. ガチョウ（5, 9, 14, 18, 23, 27...）や橋（6, 12）に止まると次のマスへジャンプし、もう一度振れます。",
        "3. 井戸（31）、迷宮（42）、牢獄（52）、ドクロ（58）に注意。63を超えた分は後ろへ跳ね返ります。",
      ],
      tournamentRules: "13羽のガチョウ、橋、宿屋、井戸、迷宮、牢獄、ドクロ、63マス目のぴったり到達ルール。",
    },
    go: {
      title: "囲碁 (Go / Weiqi / Baduk) チュートリアル",
      objective: "終局時に相手よりも多くの地（交点）とアゲハマ（捕獲石）を獲得します。",
      steps: [
        "1. 星（Hoshi）や隅を優先して空いている交点に石を打っていきます。",
        "2. 相手の連（つながった石）の上下左右のダメ（呼吸点）をすべて塞ぐと捕獲できます。",
        "3. 双方が連続でパスすると終局判定へ移行し、死石（✕）を指定してコミ6.5目で整地・計算します。",
      ],
      tournamentRules: "星への置石ハンデ、BFS連捕獲、着手禁止点（自殺手）、コウのルール、コミ6.5目。",
    },
    shogi: {
      title: "将棋 (Shogi) チュートリアル",
      objective: "駒台（持ち駒）の駒を再活用しながら相手の玉将を詰ませます。",
      steps: [
        "1. 歩兵を進めて角行（角）の斜めラインや飛車（飛）の縦ラインを開きます。",
        "2. 捕獲した駒は自分の駒台に移り、自分の手番で空いているマスに「打つ」ことができます。",
        "3. 敵陣3段目に入ると、FESA公式ルールに従って駒を「成る」ことができます。",
      ],
      tournamentRules: "持ち駒の打ち込み、二歩（Nifu）禁止、打ち歩詰め禁止、FESA成りルール。",
    },
    xiangqi: {
      title: "シャンチー（中国象棋）チュートリアル",
      objective: "3×3の宮（九宮）の中にいる相手の将（帥）を詰ませます。",
      steps: [
        "1. 車（車）と馬（馬）を展開します。馬は隣接する交点に駒があると進めません（蹩馬腿）。",
        "2. 炮（炮）は間に1つだけ台（砲架）となる駒を挟んで飛び越えることで遠くの駒を取れます。",
        "3. 王不見王（飛将ルール）：双方の将と帥が同じ縦筋で直接向かい合うことは禁止されています。",
      ],
      tournamentRules: "楚河・漢界の河、3×3の九宮、炮の砲架ジャンプ、王不見王ルール。",
    },
    chinese_checkers: {
      title: "チャイニーズチェッカー（ダイヤモンドゲーム）チュートリアル",
      objective: "自分の10個のビー玉すべてを六芒星ボードの反対側の頂点トライアングルへ移動させます。",
      steps: [
        "1. 自分の色のビー玉を選び、隣接する空きマスへ1歩進めます。",
        "2. ビー玉の梯子（ラダー）を作って中央を一気に飛び越える連続ジャンプを狙いましょう。",
        "3. ビー玉は取られません。自分の駒も相手の駒もジャンプの踏み台として利用できます。",
      ],
      tournamentRules: "121マスの六芒星ボード、隣接移動および連続マルチジャンプ。",
    },
    backgammon: {
      title: "バックギャモン チュートリアル",
      objective: "15個すべてのチェッカーをインナーボードへ集め、すべてゴール（ベアオフ）させます。",
      steps: [
        "1. 3Dダイスを振って24個のポイントに沿ってチェッカーを進めます。",
        "2. 1個だけ孤立している相手の駒（ブロット）をヒットすると中央のバーへ送ることができます。",
        "3. 形勢が有利なときはダブリングキューブ（×2, ×4, ×8）で賭け点の倍増を提案しましょう。",
      ],
      tournamentRules: "24ポイント、バーからのエンター、ベアオフ、ゾロ目4回移動、ダブリングキューブ。",
    },
    ludo: {
      title: "ルド (Ludo) チュートリアル",
      objective: "4つのトークンすべてで57ステップの周回コースを回り、中央ゴールへ到達させます。",
      steps: [
        "1. 動かすトークンを選んで3Dダイスを振ります（6が出ると基地から出撃できます）。",
        "2. 星印（★）のついた8つのマスは安全地帯で、相手の駒に捕獲されません。",
        "3. 6を出したとき、相手駒を捕獲したとき、またはゴールに到達したときは追加ロールが得られます。",
      ],
      tournamentRules: "外周52マス＋ゴール通路5マス、8つの安全スター、6での追加ロール。",
    },
    battleship: {
      title: "バトルシップ（海戦ゲーム）チュートリアル",
      objective: "敵艦隊の5隻の軍艦すべてを撃沈します（合計17ヒット）。",
      steps: [
        "1. 10×10の攻撃レーダー上の任意の座標をクリックして魚雷を発射します。",
        "2. 命中（💥）したら、上下左右の隣接マスを攻撃して艦を完全に撃沈しましょう。",
        "3. 連続攻撃ルール（Salvo）を有効にすると、命中するたびに続けて攻撃できます。",
      ],
      tournamentRules: "5隻の艦隊（長さ5, 4, 3, 3, 2）、連続攻撃オプション、再戦機能。",
    },
    mille_bornes: {
      title: "ミル・ボーヌ（1000マイル）チュートリアル",
      objective: "相手より先に走行距離メーターをぴったり1000 kmに到達させます。",
      steps: [
        "1. 青信号（走行可能）の状態のときに距離カード（50, 75, 100, 200 km）を出して進みます。",
        "2. 4枚の安全シールド（優先通行、予備タンク、パンク防止、エースドライバー）で妨害を無効化します。",
        "3. 相手の妨害カードに対して⚡クー・フレ（Coup Fourré!）を発動すると+100 kmボーナスと追加ターンを獲得します。",
      ],
      tournamentRules: "1000 kmルート、4枚のセーフティカード、妨害・修理カード、クー・フレ反撃。",
    },
    monopoly: {
      title: "モノポリー チュートリアル",
      objective: "不動産の独占（モノポリー）を築き、レンタル料で資産を増やして相手を破産させます。",
      steps: [
        "1. 3Dダイスを振って40マスのボードを周回し、GOを通過するたびに$200を受け取ります。",
        "2. 止まった未所有の物件を購入し、同じ色グループに家やホテルを均等に建設します。",
        "3. 資金が不足したときは、ボード上の所有物件を選択して抵当（モーゲージ）に入れられます。",
      ],
      tournamentRules: "40マス周回、物件購入、均等な家・ホテル建設、抵当権とレンタル料。",
    },
    crisis: {
      title: "クライシス / リスク (Crisis / TEG) チュートリアル",
      objective: "6大陸30地域を征服し、世界マップの覇権を握ります。",
      steps: [
        "1. 増援フェーズ（PlaceArmies）では、自分の領土をクリックして新しい軍隊を配備します。",
        "2. 攻撃フェーズでは、2部隊以上いる自軍領土を選択して隣接する敵領土へ侵攻します。",
        "3. 征服カードが3枚揃ったら交換して+6部隊のボーナス増援を獲得しましょう。",
      ],
      tournamentRules: "6大陸30地域、軍隊増援、3v3ダイス戦闘、カード交換ボーナス。",
    },
  },
  fr: {
    chess: {
      title: "Tutoriel d'Échecs FIDE",
      objective: "Faire échec et mat au Roi adverse ou conclure une nulle réglementaire.",
      steps: [
        "1. Contrôlez le centre de l'échiquier en avançant vos pions centraux (e2-e4 ou d2-d4).",
        "2. Développez cavaliers et fous avant la Dame et roquez pour mettre votre Roi à l'abri.",
        "3. Sur la dernière rangée, choisissez Dame, Tour, Fou ou Cavalier dans le sélecteur FIDE.",
      ],
      tournamentRules: "Promotion FIDE en 4 pièces, détection d'échec, roque, prise en passant et offre de nulle.",
    },
    checkers: {
      title: "Tutoriel de Dames Classiques",
      objective: "Capturer tous les pions adverses ou bloquer leurs mouvements.",
      steps: [
        "1. Avancez en diagonale sur les cases foncées vers le camp opposé.",
        "2. Dès qu'une prise diagonale est possible, la règle de prise obligatoire s'active automatiquement.",
        "3. En atteignant la dernière rangée, votre pion est promu Dame (♛) et se déplace en avant et en arrière.",
      ],
      tournamentRules: "Prise obligatoire, sauts multiples enchaînés et promotion en Dame.",
    },
    uno: {
      title: "Tutoriel de UNO",
      objective: "Être le premier joueur à vider entièrement sa main de cartes.",
      steps: [
        "1. Jouez une carte de même couleur ou valeur que la défausse, ou utilisez un Joker.",
        "2. Si une pénalité (+2 ou +4) est active, empilez une autre carte de pioche ou piochez le cumul.",
        "3. Appuyez sur le bouton ¡UNO! lorsqu'il vous reste 1 ou 2 cartes pour éviter toute pénalité.",
      ],
      tournamentRules: "Paquet de 108 cartes, choix de couleur sur joker et annonce ¡UNO!.",
    },
    goose: {
      title: "Tutoriel du Jeu de l'Oie",
      objective: "Atteindre le Jardin de l'Oie (case 63) avec un lancer de dés exact.",
      steps: [
        "1. Lancez les deux dés 3D pour progresser sur la spirale de 63 cases.",
        "2. En tombant sur une Oie (5, 9, 14, 18, 23, 27...) ou un Pont (6, 12), vous rebondissez et rejouez.",
        "3. Évitez le Puits (31), le Labyrinthe (42), la Prison (52) et la Tête de Mort (58). Au-delà de 63, vous reculez.",
      ],
      tournamentRules: "13 Oies, Ponts, Hôtel, Puits, Labyrinthe, Prison, Tête de Mort et rebond exact sur la 63.",
    },
    go: {
      title: "Tutoriel de Go (Weiqi / Baduk)",
      objective: "Contrôler plus d'intersections et de captures que l'adversaire en fin de partie.",
      steps: [
        "1. Placez des pierres sur les intersections vides en privilégiant les points étoiles (Hoshi).",
        "2. Entourez toutes les libertés orthogonales des chaînes adverses pour les capturer.",
        "3. Après 2 passes consécutives, marquez les pierres mortes (✕) et validez le décompte avec Komi 6.5.",
      ],
      tournamentRules: "Handicap sur points Hoshi, capture BFS, interdiction du suicide, règle du Ko et Komi 6.5.",
    },
    shogi: {
      title: "Tutoriel de Shogi",
      objective: "Capturer le Roi adverse en_parachutant les pièces capturées depuis votre Komadai.",
      steps: [
        "1. Avancez vos pions pour ouvrir la diagonale du Fou (角) et la colonne de la Tour (飛).",
        "2. Les pièces capturées vont sur votre réserve Komadai et peuvent être parachutées sur toute case libre.",
        "3. En entrant dans les 3 dernières rangées ennemies, promouvez vos pièces selon les règles FESA.",
      ],
      tournamentRules: "Parachutage depuis le Komadai, interdiction du double pion (Nifu) et promotion FESA.",
    },
    xiangqi: {
      title: "Tutoriel de Xiangqi (Échecs Chinois)",
      objective: "Capturer ou mater le Général ennemi à l'intérieur de son Palais 3×3.",
      steps: [
        "1. Déployez vos Chars (車) et Cavaliers (馬) en veillant à ne pas bloquer le pas des Cavaliers.",
        "2. Utilisez vos Canons (炮) en sautant par-dessus une pièce écran pour capturer à distance.",
        "3. Règle du Général Volant : les deux Généraux ne peuvent jamais se faire face sur une colonne ouverte.",
      ],
      tournamentRules: "Rivière Chu He / Han Jie, Palais 3×3, saut du Canon avec écran et Général Volant.",
    },
    chinese_checkers: {
      title: "Tutoriel des Dames Chinoises",
      objective: "Amener toutes vos 10 billes dans la pointe opposée de l'étoile hexagonale.",
      steps: [
        "1. Sélectionnez une bille de votre couleur et déplacez-la sur une case vide adjacente.",
        "2. Construisez des échelles de billes pour enchaîner de longs sauts d'un bout à l'autre.",
        "3. Les billes ne sont jamais capturées ; utilisez vos pièces et celles de l'adversaire comme tremplin.",
      ],
      tournamentRules: "Étoile hexagonale de 121 cases avec sauts multiples en chaîne.",
    },
    backgammon: {
      title: "Tutoriel de Backgammon",
      objective: "Ramener vos 15 dames dans votre jan intérieur et les sortir du plateau (Bear-Off).",
      steps: [
        "1. Lancez les dés 3D et avancez vos dames le long des 24 flèches.",
        "2. Frappez les dames adverses isolées (Blots) pour les envoyer sur la Barre Centrale.",
        "3. Si vous avez l'avantage, proposez de doubler l'enjeu avec le Videau (×2, ×4, ×8).",
      ],
      tournamentRules: "24 flèches, Barre Centrale, Bear-Off et Videau (Doubling Cube).",
    },
    ludo: {
      title: "Tutoriel de Ludo",
      objective: "Parcourir le circuit de 57 pas avec vos 4 pions jusqu'au but central.",
      steps: [
        "1. Choisissez lequel de vos 4 pions déplacer et lancez les dés 3D.",
        "2. Les 8 cases étoilées (★) sont des refuges sûrs où vos pions ne peuvent pas être capturés.",
        "3. Obtenir un 6 ou amener un pion au but accorde immédiatement un lancer supplémentaire.",
      ],
      tournamentRules: "52 cases + 5 de couloir final, 8 étoiles sûres et lancer supplémentaire avec un 6.",
    },
    battleship: {
      title: "Tutoriel de Bataille Navale",
      objective: "Couler les 5 navires de la flotte ennemie (17 impacts au total).",
      steps: [
        "1. Cliquez sur n'importe quelle coordonnée du radar ennemi 10×10 pour tirer une torpille.",
        "2. Après un impact (💥), ciblez les cases orthogonales adjacentes pour achever le navire.",
        "3. Activez la Règle de Rafale si vous souhaitez conserver votre tour après chaque impact.",
      ],
      tournamentRules: "Flotte de 5 navires (5, 4, 3, 3, 2), règle de rafale optionnelle et revanche.",
    },
    mille_bornes: {
      title: "Tutoriel du Mille Bornes",
      objective: "Atteindre exactement 1000 km au compteur avant votre adversaire.",
      steps: [
        "1. Posez des cartes d'Étapes (50, 75, 100, 200 km) tant que vous avez le Feu Vert.",
        "2. Déployez les 4 Bottes (Prioritaire, Citerne, Increvable, As du Volant) pour vous immuniser.",
        "3. Utilisez le bouton ⚡ Coup Fourré ! face à une attaque pour gagner +100 km et rejouer.",
      ],
      tournamentRules: "Parcours de 1000 km, 4 Bottes de sécurité et réaction Coup Fourré !.",
    },
    monopoly: {
      title: "Tutoriel de Monopoly",
      objective: "Bâtir des monopoles immobiliers et multiplier votre capital grâce aux loyers.",
      steps: [
        "1. Lancez les dés 3D pour parcourir les 40 cases du plateau et toucher 200 $ en passant par GO.",
        "2. Achetez les terrains libres où vous tombez et construisez maisons/hôtels uniformément.",
        "3. Si vous avez besoin de liquidités, hypothéquez des propriétés en les sélectionnant sur le plateau.",
      ],
      tournamentRules: "40 cases, achat de propriétés, construction uniforme de maisons/hôtels et hypothèques.",
    },
    crisis: {
      title: "Tutoriel de Crisis / Risk",
      objective: "Conquérir des territoires sur les 6 continents et dominer la carte mondiale.",
      steps: [
        "1. En Phase de Renforts (PlaceArmies), cliquez sur vos territoires pour déployer des armées.",
        "2. En Phase d'Attaque, sélectionnez un territoire avec 2+ armées et attaquez un territoire ennemi voisin.",
        "3. Dès que vous réunissez 3 cartes de conquête, échangez-les contre +6 armées supplémentaires.",
      ],
      tournamentRules: "30 territoires sur 6 continents, renforts, combat 3v3 aux dés et échange de cartes.",
    },
  },
  ko: {
    chess: {
      title: "FIDE 체스 튜토리얼",
      objective: "상대 킹을 체크메이트하거나 공식 규칙에 따른 무승부를 달성하세요.",
      steps: [
        "1. 중앙 폰(e2-e4 또는 d2-d4)을 전진시켜 보드 중앙을 장악하세요.",
        "2. 퀸을 움직이기 전에 나이트와 비숍을 전개하고 캐슬링으로 킹을 안전하게 보호하세요.",
        "3. 마지막 랭크에 도달하면 FIDE 승진 선택기에서 퀸, 룩, 비숍, 나이트 중 하나를 선택하세요.",
      ],
      tournamentRules: "FIDE 4종 기물 승진, 체크 감지, 캐슬링, 앙파상 및 무승부 제안/수락.",
    },
    checkers: {
      title: "클래식 체커 튜토리얼",
      objective: "상대의 모든 기물을 잡거나 이동 가능한 수를 완전히 봉쇄하세요.",
      steps: [
        "1. 어두운 칸을 따라 대각선 앞으로 전진하여 반대편 끝줄로 이동하세요.",
        "2. 대각선으로 뛰어넘어 잡을 수 있는 기물이 있으면 강제 포획 규칙이 자동 적용됩니다.",
        "3. 끝줄에 도달하면 킹(♛)으로 승격되어 앞뒤 모든 대각선으로 이동하고 연속 점프할 수 있습니다.",
      ],
      tournamentRules: "강제 포획, 연속 다중 점프 및 킹 승격.",
    },
    uno: {
      title: "UNO 튜토리얼",
      objective: "손에 든 카드를 가장 먼저 모두 내려놓는 플레이어가 승리합니다.",
      steps: [
        "1. 버림 더미 맨 위 카드와 색상이나 숫자가 같은 카드를 내거나 와일드 카드를 사용하세요.",
        "2. 벌칙(+2 또는 +4)이 활성화되어 있다면 같은 벌칙 카드를 중첩하거나 누적된 카드를 뽑으세요.",
        "3. 카드를 1~2장 남겼을 때 ¡UNO! 버튼을 눌러 벌칙을 방지하세요.",
      ],
      tournamentRules: "108장 덱, 와일드 색상 선택기, 벌칙 누적 및 UNO! 외치기.",
    },
    goose: {
      title: "거위 게임 튜토리얼",
      objective: "정확한 주사위 눈금으로 63번 칸(거위의 정원)에 도착하세요.",
      steps: [
        "1. 두 개의 3D 주사위를 굴려 63칸 나선형 트랙을 따라 전진하세요.",
        "2. 거위 칸(5, 9, 14, 18, 23, 27...)이나 다리 칸(6, 12)에 도착하면 다음 칸으로 점프하고 한 번 더 굴립니다.",
        "3. 우물(31), 미로(42), 감옥(52), 해골(58)을 피하세요. 63을 초과하면 남은 수만큼 뒤로 튕겨납니다.",
      ],
      tournamentRules: "13개의 거위 칸, 다리, 여관, 우물, 미로, 감옥, 해골 및 63번 칸 정확한 도달 규칙.",
    },
    go: {
      title: "바둑 (Go / Weiqi / Baduk) 튜토리얼",
      objective: "대국 종료 시 상대보다 더 많은 집(교차점)과 사석을 확보하세요.",
      steps: [
        "1. 화점(Hoshi)과 귀를 우선으로 빈 교차점에 착수하세요.",
        "2. 상대 돌 무리의 상하좌우 활로(Liberties)를 모두 막으면 해당 돌을 따낼 수 있습니다.",
        "3. 양측이 연속으로 패스하면 사석(✕)을 지정하고 덤(Komi) 6.5집을 적용해 계가를 확정합니다.",
      ],
      tournamentRules: "화점 접바둑 핸디캡, BFS 연쇄 따내기, 착수금지(자살수), 패(Ko) 규칙 및 덤 6.5집.",
    },
    shogi: {
      title: "쇼기(일본 장기) 튜토리얼",
      objective: "포획한 기물을 코마다이(기물대)에서 다시 투입하며 상대 옥장을 외통수로 잡으세요.",
      steps: [
        "1. 보병을 전진시켜 각행(角)의 대각선과 비차(飛)의 세로줄을 여세요.",
        "2. 잡은 기물은 코마다이로 이동하며 자신의 차례에 빈 칸 어디든 다시 내려놓을(타) 수 있습니다.",
        "3. 적진 마지막 3줄에 진입하면 FESA 공식 규칙에 따라 기물을 승격(성)시킬 수 있습니다.",
      ],
      tournamentRules: "코마다이 기물 재투입, 니후(이보: 같은 줄 보병 2개) 금지 및 FESA 승격 규칙.",
    },
    xiangqi: {
      title: "샹치(중국 장기) 튜토리얼",
      objective: "3×3 궁성 안에 있는 적의 장군(수)을 외통수로 몰아 잡으세요.",
      steps: [
        "1. 차(車)와 마(馬)를 전개하세요. 마는 인접한 칸에 기물이 있으면 멱이 막혀 이동할 수 없습니다.",
        "2. 포(炮)는 반드시 기물 하나를 다리(포가)로 삼아 뛰어넘어야 원거리의 적을 잡을 수 있습니다.",
        "3. 비장(Flying General) 규칙: 양측의 장군은 같은 세로줄에서 기물 없이 마주볼 수 없습니다.",
      ],
      tournamentRules: "초하/한계 강, 3×3 궁성, 포의 다리 점프 및 비장 규칙.",
    },
    chinese_checkers: {
      title: "차이니즈 체커(다이아몬드 게임) 튜토리얼",
      objective: "자신의 구슬 10개를 모두 육각별 보드의 반대편 삼각형 끝으로 이동시키세요.",
      steps: [
        "1. 자신의 구슬을 선택해 인접한 빈 구멍으로 한 칸 이동하세요.",
        "2. 구슬 사다리를 만들어 보드 중앙을 단숨에 가로지르는 연속 점프를 연결하세요.",
        "3. 구슬은 잡히지 않으며, 아군과 상대 구슬 모두 점프 징검다리로 활용할 수 있습니다.",
      ],
      tournamentRules: "121칸 육각별 보드 및 연속 다중 점프.",
    },
    backgammon: {
      title: "백개먼 튜토리얼",
      objective: "15개의 체커를 모두 자신의 홈 보드로 모아 보드 밖으로 베어오프(Bear-Off)하세요.",
      steps: [
        "1. 3D 주사위를 굴려 24개의 포인트를 따라 체커를 전진시키세요.",
        "2. 혼자 놓인 상대 체커(Blot)를 잡으면 중앙 바(Bar)로 보낼 수 있습니다.",
        "3. 형세가 유리할 때 더블링 큐브(×2, ×4, ×8)로 배점 2배 인상을 제안하세요.",
      ],
      tournamentRules: "24개 포인트, 중앙 바 재진입, 베어오프 및 더블링 큐브.",
    },
    ludo: {
      title: "루도(Ludo) 튜토리얼",
      objective: "4개의 말을 모두 57칸 트랙을 따라 중앙 골인 지점까지 완주시키세요.",
      steps: [
        "1. 이동할 말을 선택하고 3D 주사위를 굴리세요(6이 나오면 기지에서 출발할 수 있습니다).",
        "2. 별(★)이 표시된 8개의 안전 칸에서는 상대에게 잡히지 않습니다.",
        "3. 6이 나오거나 상대 말을 잡거나 골인 지점에 도착하면 즉시 추가 주사위 기회를 얻습니다.",
      ],
      tournamentRules: "외곽 52칸 + 골 통로 5칸, 8개의 안전 별 칸 및 6 굴림 추가 턴.",
    },
    battleship: {
      title: "배틀쉽(해전 게임) 튜토리얼",
      objective: "적 함대의 군함 5척을 모두 격침하세요(총 17회 명중).",
      steps: [
        "1. 10×10 적 공격 레이더의 좌표를 클릭해 어뢰를 발사하세요.",
        "2. 명중(💥)에 성공하면 상하좌우 인접 칸을 타격해 함선을 완전히 침몰시키세요.",
        "3. 일제사격(Salvo) 규칙을 켜면 명중할 때마다 연속으로 공격할 수 있습니다.",
      ],
      tournamentRules: "5척 함대(길이 5, 4, 3, 3, 2), 연속 일제사격 옵션 및 재대국.",
    },
    mille_bornes: {
      title: "밀 보른(1000마일) 튜토리얼",
      objective: "상대보다 먼저 주행 거리계를 정확히 1000 km까지 채우세요.",
      steps: [
        "1. 녹색 신호(주행 가능) 상태일 때 거리 카드(50, 75, 100, 200 km)를 내서 전진하세요.",
        "2. 4가지 안전 방패(우선통행, 보조탱크, 펑크방지, 에이스 운전자)를 배치해 공격을 무효화하세요.",
        "3. 상대의 방해 공격에 ⚡ 쿠 푸레(Coup Fourré!)로 즉각 반격하면 +100 km 보너스와 추가 턴을 얻습니다.",
      ],
      tournamentRules: "1000 km 주행 코스, 4장의 안전 카드 및 쿠 푸레! 반격.",
    },
    monopoly: {
      title: "모노폴리 튜토리얼",
      objective: "부동산 독점을 구축하고 임대료로 자산을 불려 상대를 파산시키세요.",
      steps: [
        "1. 3D 주사위를 굴려 40칸 보드를 돌고 GO를 지날 때마다 $200를 받으세요.",
        "2. 도착한 무주 부동산을 매입하고 같은 색상 그룹에 집과 호텔을 균등하게 건설하세요.",
        "3. 현금이 급히 필요할 때는 보드에서 자신의 부동산을 선택해 저당(모기지) 잡힐 수 있습니다.",
      ],
      tournamentRules: "40칸 보드, 부동산 매입, 균등한 집/호텔 건설 및 저당권 관리.",
    },
    crisis: {
      title: "크라이시스 / 리스크(Crisis / TEG) 튜토리얼",
      objective: "6개 대륙 30개 영토를 정복하고 세계 지도를 제패하세요.",
      steps: [
        "1. 병력 배치 단계(PlaceArmies)에서 아군 영토를 클릭해 증원 병력을 배치하세요.",
        "2. 공격 단계에서 병력이 2기 이상인 아군 영토를 선택해 인접한 적 영토를 공격하세요.",
        "3. 정복 카드 3장을 모으면 교환하여 +6기의 추가 병력을 획득하세요.",
      ],
      tournamentRules: "6개 대륙 30개 영토, 병력 증원, 3v3 주사위 전투 및 카드 교환.",
    },
  },
  zh: {
    chess: {
      title: "FIDE 国际象棋教程",
      objective: "将死对方国王，或达成符合规则的和棋。",
      steps: [
        "1. 推进中心兵（e2-e4 或 d2-d4）以控制棋盘中心区域。",
        "2. 在出动皇后之前先展开马和象，并通过王车易位保护国王安全。",
        "3. 兵到达底线时，可在 FIDE 升变选择器中选择皇后、车、象或马。",
      ],
      tournamentRules: "FIDE 四种棋子升变、将军检测、王车易位、吃过路兵与提和/接受和棋。",
    },
    checkers: {
      title: "经典跳棋教程",
      objective: "吃掉对手全部棋子或封锁其所有合法走法。",
      steps: [
        "1. 沿着深色方格斜向前进，朝对方底线推进。",
        "2. 一旦出现可以斜向跳过吃子的机会，强制吃子规则会自动生效。",
        "3. 到达底线后棋子会加冕为王（♛），可以向前和向后移动及连跳。",
      ],
      tournamentRules: "强制吃子、连续多步跳吃与王棋加冕。",
    },
    uno: {
      title: "UNO 纸牌教程",
      objective: "成为最先出完手中所有卡牌的玩家。",
      steps: [
        "1. 打出与弃牌堆顶颜色或数值相同的卡牌，或使用万能变色牌。",
        "2. 当存在罚抽（+2 或 +4）时，可叠加另一张罚抽牌或摸取累计罚牌。",
        "3. 手牌只剩 1 或 2 张时点击 ¡UNO! 按钮，避免被罚摸牌。",
      ],
      tournamentRules: "108 张标准牌组、万能牌选色器、罚牌叠加与 UNO! 喊牌。",
    },
    goose: {
      title: "鹅棋 (Game of the Goose) 教程",
      objective: "以精确的骰子点数刚好停在第 63 格“鹅之花园”。",
      steps: [
        "1. 投掷两颗 3D 骰子，沿着 63 格螺旋赛道前进。",
        "2. 若停在鹅格（5、9、14、18、23、27...）或桥梁（6、12），会自动跳跃并获得额外掷骰。",
        "3. 避开水井（31）、迷宫（42）、监狱（52）与骷髅（58）。超过 63 格的点数会向后反弹。",
      ],
      tournamentRules: "13 个鹅格、桥梁、客栈、水井、迷宫、监狱、骷髅及 63 格精确反弹规则。",
    },
    go: {
      title: "围棋 (Go / Weiqi / Baduk) 教程",
      objective: "终局时比对手占据更多的交叉点领地与提子数。",
      steps: [
        "1. 在空白交叉点落子，开局优先占领星位（Hoshi）与角部。",
        "2. 完全包围敌方棋链上下左右的所有“气”（Liberties）即可将其提吃。",
        "3. 双方连续两次虚手（Pass）后进入点目阶段，标记死子（✕）并以贴 6.5 目确认终局得分。",
      ],
      tournamentRules: "星位让子、BFS 棋链提子、禁入点（禁自杀）、劫争（Ko）规则与贴 6.5 目。",
    },
    shogi: {
      title: "日本将棋 (Shogi) 教程",
      objective: "灵活打入驹台（持驹）上的俘获棋子，将死对方玉将。",
      steps: [
        "1. 推进步兵打开角行（角）的斜线与飞车（飞）的纵线。",
        "2. 吃掉的对方棋子会放入你的驹台，轮到你时可“打入”到棋盘上任何合法空格。",
        "3. 进入敌阵最后三行时，可按照 FESA 官方规则将棋子“成”（升变）。",
      ],
      tournamentRules: "驹台持驹打入、二步（Nifu）禁手、打步诘禁手与 FESA 升变规则。",
    },
    xiangqi: {
      title: "中国象棋 (Xiangqi) 教程",
      objective: "在对方 3×3 九宫格内将死或困毙敌方将（帅）。",
      steps: [
        "1. 迅速出动车（車）和马（馬），注意马脚被堵（蹩马腿）时无法向该方向起跳。",
        "2. 炮（炮）吃子必须隔着恰好一枚棋子（炮架）才能远距离轰击。",
        "3. 牢记“飞将”规则：双方将与帅绝不能在同一条无遮挡的纵线上直接照面。",
      ],
      tournamentRules: "楚河汉界、3×3 九宫格、炮隔山打牛与白脸将（飞将）禁手。",
    },
    chinese_checkers: {
      title: "中国跳棋 (Sternhalma) 教程",
      objective: "将己方全部 10 颗弹珠移入六角星棋盘正对面的目标三角形。",
      steps: [
        "1. 选择一颗己方颜色的弹珠，移动到相邻的空位。",
        "2. 搭建弹珠阶梯，利用连续多步跳跃一口气横跨星形中心。",
        "3. 弹珠不会被吃掉；你可以同时利用己方和对手的弹珠作为跳板。",
      ],
      tournamentRules: "121 孔六角星形棋盘，支持相邻单步与连续长距离连跳。",
    },
    backgammon: {
      title: "双陆棋 (Backgammon) 教程",
      objective: "将己方全部 15 枚棋子移入内盘并全部离盘（Bear-Off）。",
      steps: [
        "1. 投掷 3D 骰子，沿着 24 个三角点推进己方棋子。",
        "2. 击中落单的敌方棋子（Blot）可将其打入中央栏（Bar）。",
        "3. 占据明显局势优势时，可使用加倍方块（×2、×4、×8）提议翻倍比分。",
      ],
      tournamentRules: "24 个三角点、中央栏重入、Bear-Off 离盘与加倍方块。",
    },
    ludo: {
      title: "飞行棋 (Ludo) 教程",
      objective: "引导己方 4 枚棋子走完 57 步环形赛道进入中央终点。",
      steps: [
        "1. 选择要移动的棋子并投掷 3D 骰子（掷出 6 可让棋子从基地起飞）。",
        "2. 标有星号（★）的 8 个格子是安全区，停在上面的棋子不会被吃掉。",
        "3. 掷出 6、吃掉敌方棋子或有棋子抵达终点时，立即获得一次额外掷骰机会。",
      ],
      tournamentRules: "外圈 52 格 + 终点跑道 5 格、8 个安全星格与掷 6 奖励回合。",
    },
    battleship: {
      title: "海战棋 (Battleship) 教程",
      objective: "击沉敌方舰队的全部 5 艘军舰（共计 17 次命中）。",
      steps: [
        "1. 点击 10×10 敌方攻击雷达上的任意坐标发射鱼雷。",
        "2. 取得命中（💥）后，继续轰击上下左右相邻坐标直至彻底击沉该舰。",
        "3. 若开启“连射规则”（Salvo），每次命中敌舰后都可继续保持开火回合。",
      ],
      tournamentRules: "5 艘战舰舰队（长度 5、4、3、3、2）、可选连射规则与快速重赛。",
    },
    mille_bornes: {
      title: "千里之行 (Mille Bornes) 教程",
      objective: "比对手率先在里程表上精确行驶到 1000 公里。",
      steps: [
        "1. 在拥有绿灯（畅通道路）时打出里程卡（50、75、100、200 公里）累计行程。",
        "2. 部署 4 张王牌护盾（优先通行、备用油箱、防爆轮胎、王牌车手）获得永久免疫。",
        "3. 面对敌方障碍攻击时点击 ⚡ Coup Fourré! 瞬间反击，可获 +100 公里奖励与额外回合。",
      ],
      tournamentRules: "1000 公里赛程、4 张王牌安全护盾与 Coup Fourré! 绝地反击。",
    },
    monopoly: {
      title: "大富翁 (Monopoly) 教程",
      objective: "建立地产垄断并通过收取高额租金扩大资本，直至对手破产。",
      steps: [
        "1. 投掷 3D 骰子环游 40 格棋盘，每次经过 GO 起点均可领取 $200。",
        "2. 购买停留处的无主地产，并在同色街区均匀建造房屋与旅馆。",
        "3. 急需现金周转时，可在棋盘上选中己方地产进行抵押贷款。",
      ],
      tournamentRules: "40 格标准棋盘、地产购买、均匀建造房屋/旅馆与抵押机制。",
    },
    crisis: {
      title: "全球危机 / 战地风云 (Crisis / TEG) 教程",
      objective: "跨越 6 大洲征服 30 个领土并统治全球版图。",
      steps: [
        "1. 在增援阶段（PlaceArmies），点击己方领土部署新兵力。",
        "2. 在进攻阶段，选择拥有 2 支以上军队的己方领土向相邻敌方领土发起进攻。",
        "3. 集齐 3 张领土征服卡后，可兑换 +6 支额外奖励大军。",
      ],
      tournamentRules: "6 大洲 30 个领土、兵力增援、3v3 骰子会战与卡牌兑换。",
    },
  },
};

export function getLocalizedTutorialContent(
  gameId: string,
  locale: SupportedLocale,
  fallbackSpec: GameTutorialSpec
): LocalizedTutorialText {
  if (locale === "es") {
    return {
      title: fallbackSpec.title,
      objective: fallbackSpec.objective,
      steps: [
        fallbackSpec.steps[0] || "",
        fallbackSpec.steps[1] || "",
        fallbackSpec.steps[2] || "",
      ],
      tournamentRules: fallbackSpec.tournamentRules,
    };
  }
  const localized = TUTORIALS_14_BY_LOCALE[locale]?.[gameId];
  if (localized) return localized;
  return {
    title: fallbackSpec.title,
    objective: fallbackSpec.objective,
    steps: [
      fallbackSpec.steps[0] || "",
      fallbackSpec.steps[1] || "",
      fallbackSpec.steps[2] || "",
    ],
    tournamentRules: fallbackSpec.tournamentRules,
  };
}

export interface LocalizedDocModalUi {
  dialogAriaLabel: string;
  headerKicker: string;
  headerTitle: string;
  closeAriaLabel: string;
  tabUsage: string;
  tabGames: string;
  tabDeveloper: string;
  categoryBadgeUsage: string;
  categoryBadgeGames: string;
  categoryBadgeDeveloper: string;
  searchPlaceholder: string;
  emptySearchPrefix: string;
  emptySearchSuffix: string;
  copyBtn: string;
  copiedBtn: string;
  footerSyncText: string;
  closeBtn: string;
}

export const DOC_MODAL_UI_BY_LOCALE: Record<SupportedLocale, LocalizedDocModalUi> = {
  es: {
    dialogAriaLabel: "Centro de Documentación de Uso y Desarrollo Web React + WASM",
    headerKicker: "Documentación Oficial Integrada · docs/WEB_USER_GUIDE.md & docs/WEB_REACT_DEVELOPER_GUIDE.md",
    headerTitle: "Manual de Uso y Guía de Desarrollo Web (React + TypeScript + WASM)",
    closeAriaLabel: "Cerrar documentación",
    tabUsage: "Manual de Uso",
    tabGames: "Reglas 14 Juegos",
    tabDeveloper: "Desarrollo React + WASM",
    categoryBadgeUsage: "Manual de Uso",
    categoryBadgeGames: "Catálogo Canónico 14 Juegos",
    categoryBadgeDeveloper: "Ingeniería Web (React + TypeScript + WASM)",
    searchPlaceholder: "Buscar (ej. WASM, Relay, ELO, Shogi, SVG...)",
    emptySearchPrefix: "No se encontraron secciones para",
    emptySearchSuffix: "Prueba con términos como WASM, Relay, Torneos, ELO o el nombre de cualquiera de los 14 juegos.",
    copyBtn: "Copiar",
    copiedBtn: "Copiado",
    footerSyncText: "Documentación sincronizada con docs/WEB_USER_GUIDE.md y docs/WEB_REACT_DEVELOPER_GUIDE.md",
    closeBtn: "Cerrar",
  },
  en: {
    dialogAriaLabel: "Usage & React + WASM Web Development Documentation Center",
    headerKicker: "Integrated Official Documentation · docs/WEB_USER_GUIDE.md & docs/WEB_REACT_DEVELOPER_GUIDE.md",
    headerTitle: "User Manual & Web Development Guide (React + TypeScript + WASM)",
    closeAriaLabel: "Close documentation",
    tabUsage: "User Manual",
    tabGames: "14 Games Rules",
    tabDeveloper: "React + WASM Dev",
    categoryBadgeUsage: "User Manual",
    categoryBadgeGames: "Canonical 14-Game Catalog",
    categoryBadgeDeveloper: "Web Engineering (React + TypeScript + WASM)",
    searchPlaceholder: "Search (e.g. WASM, Relay, ELO, Shogi, SVG...)",
    emptySearchPrefix: "No sections found for",
    emptySearchSuffix: "Try terms like WASM, Relay, Tournaments, ELO, or any of the 14 games.",
    copyBtn: "Copy",
    copiedBtn: "Copied",
    footerSyncText: "Documentation synced with docs/WEB_USER_GUIDE.md and docs/WEB_REACT_DEVELOPER_GUIDE.md",
    closeBtn: "Close",
  },
  pt: {
    dialogAriaLabel: "Centro de Documentação de Uso e Desenvolvimento Web React + WASM",
    headerKicker: "Documentação Oficial Integrada · docs/WEB_USER_GUIDE.md & docs/WEB_REACT_DEVELOPER_GUIDE.md",
    headerTitle: "Manual de Uso e Guia de Desenvolvimento Web (React + TypeScript + WASM)",
    closeAriaLabel: "Fechar documentação",
    tabUsage: "Manual de Uso",
    tabGames: "Regras 14 Jogos",
    tabDeveloper: "Desenvolvimento React + WASM",
    categoryBadgeUsage: "Manual de Uso",
    categoryBadgeGames: "Catálogo Canônico 14 Jogos",
    categoryBadgeDeveloper: "Engenharia Web (React + TypeScript + WASM)",
    searchPlaceholder: "Buscar (ex. WASM, Relay, ELO, Shogi, SVG...)",
    emptySearchPrefix: "Nenhuma seção encontrada para",
    emptySearchSuffix: "Tente termos como WASM, Relay, Torneios, ELO ou qualquer um dos 14 jogos.",
    copyBtn: "Copiar",
    copiedBtn: "Copiado",
    footerSyncText: "Documentação sincronizada com docs/WEB_USER_GUIDE.md e docs/WEB_REACT_DEVELOPER_GUIDE.md",
    closeBtn: "Fechar",
  },
  it: {
    dialogAriaLabel: "Centro di Documentazione d'Uso e Sviluppo Web React + WASM",
    headerKicker: "Documentazione Ufficiale Integrata · docs/WEB_USER_GUIDE.md & docs/WEB_REACT_DEVELOPER_GUIDE.md",
    headerTitle: "Manuale d'Uso e Guida allo Sviluppo Web (React + TypeScript + WASM)",
    closeAriaLabel: "Chiudi documentazione",
    tabUsage: "Manuale d'Uso",
    tabGames: "Regole 14 Giochi",
    tabDeveloper: "Sviluppo React + WASM",
    categoryBadgeUsage: "Manuale d'Uso",
    categoryBadgeGames: "Catalogo Canonico 14 Giochi",
    categoryBadgeDeveloper: "Ingegneria Web (React + TypeScript + WASM)",
    searchPlaceholder: "Cerca (es. WASM, Relay, ELO, Shogi, SVG...)",
    emptySearchPrefix: "Nessuna sezione trovata per",
    emptySearchSuffix: "Prova termini come WASM, Relay, Tornei, ELO o uno dei 14 giochi.",
    copyBtn: "Copia",
    copiedBtn: "Copiato",
    footerSyncText: "Documentazione sincronizzata con docs/WEB_USER_GUIDE.md e docs/WEB_REACT_DEVELOPER_GUIDE.md",
    closeBtn: "Chiudi",
  },
  de: {
    dialogAriaLabel: "Dokumentationszentrum für Nutzung und React + WASM Webentwicklung",
    headerKicker: "Integrierte Offizielle Dokumentation · docs/WEB_USER_GUIDE.md & docs/WEB_REACT_DEVELOPER_GUIDE.md",
    headerTitle: "Benutzerhandbuch & Web-Entwicklungsleitfaden (React + TypeScript + WASM)",
    closeAriaLabel: "Dokumentation schließen",
    tabUsage: "Benutzerhandbuch",
    tabGames: "Regeln 14 Spiele",
    tabDeveloper: "React + WASM Entwicklung",
    categoryBadgeUsage: "Benutzerhandbuch",
    categoryBadgeGames: "Kanonischer 14-Spiele-Katalog",
    categoryBadgeDeveloper: "Web-Engineering (React + TypeScript + WASM)",
    searchPlaceholder: "Suchen (z. B. WASM, Relay, ELO, Shogi, SVG...)",
    emptySearchPrefix: "Keine Abschnitte gefunden für",
    emptySearchSuffix: "Versuche Begriffe wie WASM, Relay, Turniere, ELO oder eines der 14 Spiele.",
    copyBtn: "Kopieren",
    copiedBtn: "Kopiert",
    footerSyncText: "Dokumentation synchronisiert mit docs/WEB_USER_GUIDE.md und docs/WEB_REACT_DEVELOPER_GUIDE.md",
    closeBtn: "Schließen",
  },
  ja: {
    dialogAriaLabel: "利用マニュアル＆React + WASM Web開発ドキュメントセンター",
    headerKicker: "統合公式ドキュメント · docs/WEB_USER_GUIDE.md & docs/WEB_REACT_DEVELOPER_GUIDE.md",
    headerTitle: "利用マニュアル＆Web開発ガイド (React + TypeScript + WASM)",
    closeAriaLabel: "ドキュメントを閉じる",
    tabUsage: "利用マニュアル",
    tabGames: "全14ゲームルール",
    tabDeveloper: "React + WASM開発",
    categoryBadgeUsage: "利用マニュアル",
    categoryBadgeGames: "全14公式ゲームカタログ",
    categoryBadgeDeveloper: "Webエンジニアリング (React + TypeScript + WASM)",
    searchPlaceholder: "検索 (例: WASM, Relay, ELO, Shogi, SVG...)",
    emptySearchPrefix: "一致するセクションが見つかりません：",
    emptySearchSuffix: "WASM、Relay、ELO、または14ゲームの名称で検索してください。",
    copyBtn: "コピー",
    copiedBtn: "コピー済",
    footerSyncText: "docs/WEB_USER_GUIDE.md および docs/WEB_REACT_DEVELOPER_GUIDE.md と同期済み",
    closeBtn: "閉じる",
  },
  fr: {
    dialogAriaLabel: "Centre de Documentation d'Utilisation et Développement Web React + WASM",
    headerKicker: "Documentation Officielle Intégrée · docs/WEB_USER_GUIDE.md & docs/WEB_REACT_DEVELOPER_GUIDE.md",
    headerTitle: "Manuel d'Utilisation et Guide de Développement Web (React + TypeScript + WASM)",
    closeAriaLabel: "Fermer la documentation",
    tabUsage: "Manuel d'Utilisation",
    tabGames: "Règles des 14 Jeux",
    tabDeveloper: "Développement React + WASM",
    categoryBadgeUsage: "Manuel d'Utilisation",
    categoryBadgeGames: "Catalogue Canonique des 14 Jeux",
    categoryBadgeDeveloper: "Ingénierie Web (React + TypeScript + WASM)",
    searchPlaceholder: "Rechercher (ex. WASM, Relay, ELO, Shogi, SVG...)",
    emptySearchPrefix: "Aucune section trouvée pour",
    emptySearchSuffix: "Essayez des termes comme WASM, Relay, Tournois, ELO ou l'un des 14 jeux.",
    copyBtn: "Copier",
    copiedBtn: "Copié",
    footerSyncText: "Documentation synchronisée avec docs/WEB_USER_GUIDE.md et docs/WEB_REACT_DEVELOPER_GUIDE.md",
    closeBtn: "Fermer",
  },
  ko: {
    dialogAriaLabel: "사용 매뉴얼 및 React + WASM 웹 개발 문서 센터",
    headerKicker: "통합 공식 문서 · docs/WEB_USER_GUIDE.md & docs/WEB_REACT_DEVELOPER_GUIDE.md",
    headerTitle: "사용 매뉴얼 및 웹 개발 가이드 (React + TypeScript + WASM)",
    closeAriaLabel: "문서 닫기",
    tabUsage: "사용 매뉴얼",
    tabGames: "14개 게임 규칙",
    tabDeveloper: "React + WASM 개발",
    categoryBadgeUsage: "사용 매뉴얼",
    categoryBadgeGames: "14개 공식 게임 카탈로그",
    categoryBadgeDeveloper: "웹 엔지니어링 (React + TypeScript + WASM)",
    searchPlaceholder: "검색 (예: WASM, Relay, ELO, Shogi, SVG...)",
    emptySearchPrefix: "검색 결과가 없습니다:",
    emptySearchSuffix: "WASM, Relay, ELO 또는 14개 게임 이름으로 검색해 보세요.",
    copyBtn: "복사",
    copiedBtn: "복사됨",
    footerSyncText: "docs/WEB_USER_GUIDE.md 및 docs/WEB_REACT_DEVELOPER_GUIDE.md와 동기화됨",
    closeBtn: "닫기",
  },
  zh: {
    dialogAriaLabel: "使用手册与 React + WASM Web 开发文档中心",
    headerKicker: "官方集成文档 · docs/WEB_USER_GUIDE.md & docs/WEB_REACT_DEVELOPER_GUIDE.md",
    headerTitle: "使用手册与 Web 开发指南 (React + TypeScript + WASM)",
    closeAriaLabel: "关闭文档",
    tabUsage: "使用手册",
    tabGames: "14款游戏规则",
    tabDeveloper: "React + WASM 开发",
    categoryBadgeUsage: "使用手册",
    categoryBadgeGames: "14款标准游戏目录",
    categoryBadgeDeveloper: "Web 工程 (React + TypeScript + WASM)",
    searchPlaceholder: "搜索（例如 WASM, Relay, ELO, Shogi, SVG...）",
    emptySearchPrefix: "未找到相关章节：",
    emptySearchSuffix: "请尝试搜索 WASM、Relay、ELO 或任意一款游戏名称。",
    copyBtn: "复制",
    copiedBtn: "已复制",
    footerSyncText: "文档已与 docs/WEB_USER_GUIDE.md 和 docs/WEB_REACT_DEVELOPER_GUIDE.md 同步",
    closeBtn: "关闭",
  },
};

type LocalizedDocSectionOverride = Pick<
  DocumentationSection,
  "title" | "subtitle" | "paragraphs" | "bulletPoints"
> & {
  codeLabel?: string;
};

const DOC_SECTIONS_BY_LOCALE: Record<
  Exclude<SupportedLocale, "es">,
  Record<string, LocalizedDocSectionOverride>
> = {
  en: {
    "usage-quickstart": {
      title: "01. Quick Start & Match Modes",
      subtitle: "Local Hotseat, vs Rust AI (4 levels), Online Relay Rooms & Spectator",
      paragraphs: [
        "The OpenTable Web application lets you play any of the 14 canonical board games directly in your browser with zero setup.",
        "From the workspace toolbar you can switch among the 14 games at any time and choose one of the 4 operation modes:",
      ],
      bulletPoints: [
        "Local Hotseat (2 Players): Both players share the device taking turns on the same board.",
        "vs Rust AI (4 Levels): Play as Player 1 against the deterministic AI engine on Easy (1000 ELO), Medium (1200 ELO), Hard (1450 ELO), or Master (1700 ELO).",
        "Online Relay / QR: Create a 6-character room with an instant QR code or join as Player 2 from another browser or Godot client.",
        "Spectator Mode: Watch live matches in real time with a read-only board and room chat access.",
      ],
    },
    "usage-matchmaking-elo": {
      title: "02. Automated ELO Range Matchmaking Queue",
      subtitle: "Competitive pairing in open_table_relay with progressive window expansion",
      paragraphs: [
        "In the 'Online Rooms' tab, the Automated Matchmaking Queue pairs you with another player searching for the same game within a compatible ELO window.",
        "The Relay server verifies the symmetric condition |ELO_A - ELO_B| <= min(delta_A, delta_B) to guarantee balanced matches.",
      ],
      bulletPoints: [
        "Select initial tolerance: ±150 ELO (Strict), ±300 ELO (Standard), or ±800 ELO (Open).",
        "If no immediate opponent is found, the window expands automatically every 5 seconds.",
        "At any time you can click 'Calibrated AI Sparring' to start immediately against an AI level matched to your current ELO.",
      ],
    },
    "usage-tournaments-elo": {
      title: "03. Tournament Organizer & ELO K=32 Ranking",
      subtitle: "Round-Robin Leagues (Berger Tables), Single-Elimination & 12 Achievements",
      paragraphs: [
        "The 'Tournaments' tab lets you organize competitions combining human players and AI bots in any of the 14 games.",
        "The 'ELO Ranking' tab maintains your persistent competitive profile using the official FIDE K=32 formula, per-game stats, and 12 unlockable achievements.",
      ],
      bulletPoints: [
        "Round-Robin League (Berger System): All-play-all schedule with automatic standings.",
        "Single Elimination (Knockout): Bracket progression with automatic winner advancement to the Final.",
        "Direct Board Launch: Click 'Play on Board' on any pending match to play it live; results automatically update the tournament and your ELO profile.",
      ],
    },
    "usage-analyzer-replay": {
      title: "04. Post-Match Analyzer & Replay Viewer",
      subtitle: "SVG advantage curve [-100, +100] and move quality classification",
      paragraphs: [
        "The 'Analyzer' tab reconstructs any finished or ongoing match step-by-step across all 14 games and computes the positional advantage curve from Player 1's perspective.",
        "Additionally, the Replay Viewer in the menu drawer lets you step backward or forward turn-by-turn, export the match to JSON, or import a previous log.",
      ],
      bulletPoints: [
        "★ Best and ✓ Good move classifications compared against the Level 4 Master AI.",
        "? Inaccuracy and ?? Blunder detection for critical turning points.",
        "Click any node on the SVG curve or table row to inspect that exact turn state and load it onto the active board.",
      ],
    },
    "usage-accessibility-pwa": {
      title: "05. Tournament Clocks, Okabe-Ito Accessibility, Audio & PWA",
      subtitle: "Visual theme combo list, Web Audio API synthesis & 100% offline play",
      paragraphs: [
        "The menu drawer includes official time controls (Blitz 3+2, Rapid 10+0, and Japanese Byo-yomi for Go/Shogi), a 3-theme combo list, and full accessibility support.",
      ],
      bulletPoints: [
        "Visual Themes Combo List: Dark Stone (default), Blue Night, and Green Jade.",
        "Okabe-Ito Colorblind Mode: Replaces ambiguous red/green palettes with high-contrast blue (#0072B2) and vermilion (#D55E00).",
        "Procedural Audio: Web Audio API synthesized sound effects (moves, dice, cards, victory, and clock alerts) with zero external MP3 dependencies.",
        "PWA Installation: Click 'Install PWA' in the top bar to install OpenTable on desktop or mobile and play 100% offline.",
      ],
    },
    "games-classic-oriental": {
      title: "Games 01–06: Classic & Eastern Strategy",
      subtitle: "Chess, Checkers, Go, Shogi, Xiangqi & Chinese Checkers",
      paragraphs: [
        "All grid and intersection boards automatically highlight legal destination squares when you select one of your pieces or a captured piece in hand (Komadai in Shogi).",
      ],
      bulletPoints: [
        "01. Chess (chess_game): Click a piece and then a highlighted destination square. Includes castling, en passant, check detection, and FIDE 4-piece promotion.",
        "02. Checkers (checkers_game): Mandatory capture, chained multi-jumps, and King crowning.",
        "03. Go (go_game): Click any empty intersection to place a stone (with BFS chain capture, suicide & Ko validation) or pass turn (2 passes end with 6.5 Komi scoring).",
        "04. Shogi (shogi_game): 9×9 board with captured piece stands (Komadai), drops, Nifu validation, and FESA promotion.",
        "05. Xiangqi (xiangqi_game): 9×10 board with central River, 3×3 Palaces, Cannon screen jump, and Flying General prohibition.",
        "06. Chinese Checkers (chinese_checkers_game): 121-hole 6-pointed star with single steps and chained multi-jumps to the opposite triangle.",
      ],
    },
    "games-dice-cards-tactical": {
      title: "Games 07–14: Dice, Cards, Naval Combat & Global Strategy",
      subtitle: "UNO, Game of the Goose, Backgammon, Ludo, Battleship, Mille Bornes, Monopoly & Crisis/Risk",
      paragraphs: [
        "Games featuring 3D dice, card hands, or tactical phases expose clear contextual buttons for every stage of the turn.",
      ],
      bulletPoints: [
        "07. UNO (uno_game): Click a matching color/value card or Wild card, press 'UNO!' when down to 1–2 cards, or draw from the deck.",
        "08. Game of the Goose (goose_game): Roll the 3D dice to advance along the 63-square spiral with automatic Goose jumps, Bridges, Inn, Well, Maze, Jail, and Skull.",
        "09. Backgammon (backgammon_game): Roll 2 dice and move along the 24 points, re-enter from the Center Bar, bear off, or offer the Doubling Cube.",
        "10. Ludo (ludo_game): Roll the 3D dice (a 6 deploys from yard and grants a bonus roll) and advance your 4 tokens along the 15×15 cross track.",
        "11. Battleship (battleship_game): Dual 10×10 grids with your 5 illustrated ships on defense and coordinate torpedo targeting on the Attack Radar.",
        "12. Mille Bornes (mille_bornes_game): Play distance cards (50–200 km), hazards, remedies, and 4 Safety shields (with Coup Fourré!) up to 1000 km.",
        "13. Monopoly (monopoly_game): Roll dice across 40 spaces, buy properties, build houses/hotels evenly, and manage mortgages.",
        "14. Crisis / Risk (crisis_game): Conquer 30 territories across 6 continents with army reinforcements, 3v3 dice combat, and 3-card trades.",
      ],
    },
    "dev-verify-guarantee": {
      title: "Pillar 1. How to Verify & Audit 100% Functional Readiness",
      subtitle: "CLI verification script, automated test suites & live Self-Test E2E Diagnostics Panel",
      paragraphs: [
        "To verify at any moment that the React + WASM Web client is 100% operational, you have both the live E2E Diagnostics Center in the UI and the automated CLI verification gate.",
        "The verification script runs static TypeScript checks, all automated test suites (covering all 14 games, canonical rules, and 9-language i18n), Vite production build, and documentation checks.",
      ],
      bulletPoints: [
        "Single-command verification from the SDK root: bash tools/verify_web_client.sh",
        "Direct regression test execution: npm --prefix web_client test",
        "Programmatic verification in code: import runFullSystemDiagnostics() from src/components/common/SystemDiagnosticsPanel.tsx.",
      ],
      codeLabel: "Full Functional Verification Commands (Terminal / CI)",
    },
    "dev-architecture-wasm": {
      title: "Pillar 2. React Architecture + Rust WASM Bridge & Isomorphic TS Engine",
      subtitle: "Unified contract between open_table_wasm (Rust) and WasmGameBridge (TypeScript)",
      paragraphs: [
        "The Web client cleanly decouples the React visual layer from rule execution through WasmGameBridge (src/wasm_pkg/index.ts), matching the #[wasm_bindgen] contract of open_table_wasm.",
        "All 14 games share a deterministic JSON state, legal move generator, command reducer, AI stepper, and replay log serializer.",
      ],
      bulletPoints: [
        "start_local_match / start_ai_match: Initializes a clean deterministic game session.",
        "get_state_json() & get_legal_moves_json(player_id): Returns the canonical board snapshot and legal moves.",
        "send_command_json(player_id, cmd_json) & step_ai_if_needed(): Applies moves and steps the AI.",
        "export_log_json() & apply_sync_log_json(): Serializes and reconstructs matches for Replay, Analyzer, and Relay sync.",
      ],
      codeLabel: "WasmGameBridge Contract in React / TypeScript",
    },
    "dev-svg-boards-extension": {
      title: "Pillar 3. Guide to Creating or Extending SVG Boards & Game Engines",
      subtitle: "Standard component pattern in src/components/boards/<Game>Board.tsx",
      paragraphs: [
        "Each of the 14 games has a dedicated component in src/components/boards/<Game>Board.tsx receiving immutable props: stateJson, legalMovesJson, isLocalTurnAllowed, localPlayerId, and onDispatchCommand.",
        "Boards never mutate state locally: they highlight valid targets from legalMovesJson and dispatch JSON commands via onDispatchCommand.",
      ],
      bulletPoints: [
        "Step 1: Define initial state, legal moves, command reducer, and AI in the bridge.",
        "Step 2: Create a responsive SVG board component in src/components/boards/.",
        "Step 3: Register the game in CATALOG_14_GAMES and add its positional evaluator.",
        "Step 4: Add regression and canonical rule tests so the E2E Diagnostics Center audits it automatically.",
      ],
      codeLabel: "React + SVG Board Component Template",
    },
    "dev-relay-protocol-pwa": {
      title: "Pillar 4. Relay WebSocket Protocol, ELO Matchmaking & PWA Deployment",
      subtitle: "Interoperability with open_table_relay and CI/CD pipeline to GitHub Pages",
      paragraphs: [
        "RelayWebSocketClient (src/bridge/relayClient.ts) communicates with the Rust open_table_relay server using typed JSON frames and supports multi-tab BroadcastChannel sync when running locally.",
        "The PWA manifest and Service Worker cache the entire application shell so all 14 games and AI levels work 100% offline.",
      ],
      bulletPoints: [
        "Create / Join / Spectate room: { action: 'create' }, { action: 'join', code }, { action: 'spectate', code }.",
        "ELO Matchmaking Queue: { action: 'queue', game_type, elo, max_elo_delta } -> { event: 'matched', code, player_id }.",
        "Real-time relay envelopes for moves, state sync, ELO sync, and room chat.",
      ],
      codeLabel: "open_table_relay Protocol JSON Messages",
    },
  },
  pt: {
    "usage-quickstart": {
      title: "01. Início Rápido e Modos de Partida",
      subtitle: "Hotseat Local, vs IA Rust (4 níveis), Salas Online Relay e Espectador",
      paragraphs: [
        "A aplicação Web do OpenTable permite jogar qualquer um dos 14 jogos de tabuleiro canônicos diretamente no navegador sem configuração adicional.",
        "Na barra de ferramentas você pode alternar entre os 14 jogos a qualquer momento e escolher um dos 4 modos de operação:",
      ],
      bulletPoints: [
        "Hotseat Local (2 Jogadores): Ambos os jogadores compartilham o dispositivo alternando turnos no mesmo tabuleiro.",
        "vs IA Rust (4 Níveis): Jogue como Jogador 1 contra o motor de IA determinístico nos níveis Fácil (1000 ELO), Médio (1200 ELO), Difícil (1450 ELO) e Mestre (1700 ELO).",
        "Online Relay / QR: Crie uma sala de 6 caracteres com código QR instantâneo ou entre como Jogador 2 a partir de outro navegador.",
        "Modo Espectador: Assista a partidas em andamento em tempo real com tabuleiro somente leitura e chat da sala.",
      ],
    },
    "usage-matchmaking-elo": {
      title: "02. Fila de Matchmaking Automático por Faixa ELO",
      subtitle: "Pareamento competitivo no open_table_relay com expansão progressiva",
      paragraphs: [
        "Na aba 'Salas Online', a Fila de Matchmaking Automático encontra outro jogador que procure o mesmo jogo dentro de uma janela de ELO compatível.",
        "O servidor Relay verifica a condição simétrica |ELO_A - ELO_B| <= min(delta_A, delta_B) para garantir partidas equilibradas.",
      ],
      bulletPoints: [
        "Selecione a tolerância inicial: ±150 ELO (Restrito), ±300 ELO (Padrão) ou ±800 ELO (Aberto).",
        "Se não houver oponente imediato, a janela se expande automaticamente a cada 5 segundos.",
        "A qualquer momento você pode clicar em 'Sparring IA Calibrada' para jogar imediatamente contra uma IA ajustada ao seu ELO.",
      ],
    },
    "usage-tournaments-elo": {
      title: "03. Organizador de Torneios e Ranking ELO K=32",
      subtitle: "Ligas Round-Robin (Tabelas de Berger), Eliminatória Direta e 12 Conquistas",
      paragraphs: [
        "A aba 'Torneios' permite organizar competições combinando jogadores humanos e bots de IA em qualquer um dos 14 jogos.",
        "A aba 'Ranking ELO' mantém seu perfil competitivo persistente com a fórmula oficial FIDE K=32, estatísticas por jogo e 12 conquistas desbloqueáveis.",
      ],
      bulletPoints: [
        "Liga Round-Robin (Sistema Berger): Todos contra todos com classificação automática.",
        "Eliminatória Direta (Knockout): Chaveamento com avanço automático do vencedor até a Final.",
        "Lançamento direto ao tabuleiro: Clique em 'Jogar no Tabuleiro' em qualquer confronto pendente para disputá-lo ao vivo.",
      ],
    },
    "usage-analyzer-replay": {
      title: "04. Analisador Pós-Partida e Visualizador de Replay",
      subtitle: "Gráfico SVG de vantagem [-100, +100] e classificação de jogadas",
      paragraphs: [
        "A aba 'Analisador' reconstrói passo a passo qualquer partida nos 14 jogos e calcula a curva de vantagem posicional sob a perspectiva do Jogador 1.",
        "Além disso, o Visualizador de Replay no menu lateral permite voltar ou avançar turno a turno e exportar/importar JSON.",
      ],
      bulletPoints: [
        "★ Ótima e ✓ Boa comparadas com a linha recomendada pela IA Mestre (Nível 4).",
        "? Imprecisão e ?? Erro Crítico para identificar viradas táticas.",
        "Clique em qualquer nó da curva SVG ou linha da tabela para inspecionar o turno e carregá-lo no tabuleiro ativo.",
      ],
    },
    "usage-accessibility-pwa": {
      title: "05. Relógios de Torneio, Acessibilidade Okabe-Ito, Áudio e PWA",
      subtitle: "Combo list de temas visuais, síntese Web Audio API e jogo 100% offline",
      paragraphs: [
        "O menu lateral inclui controles de tempo oficiais (Blitz 3+2, Rápido 10+0 e Byo-yomi japonês), seletor combo list de 3 temas visuais e suporte completo de acessibilidade.",
      ],
      bulletPoints: [
        "Combo List de Temas Visuais: Pedra Escura (padrão), Noite Azul e Jade Verde.",
        "Modo Daltônico Okabe-Ito: Substitui paletas vermelho/verde ambíguas por azul (#0072B2) e vermelhão (#D55E00) de alto contraste.",
        "Áudio Procedural: Efeitos sintetizados via Web Audio API sem arquivos MP3 externos.",
        "Instalação PWA: Clique em 'Instalar PWA' no topo para instalar o OpenTable e jogar 100% offline.",
      ],
    },
    "games-classic-oriental": {
      title: "Jogos 01–06: Estratégia Clássica e Oriental",
      subtitle: "Xadrez, Damas, Go, Shogi, Xiangqi e Damas Chinesas",
      paragraphs: [
        "Todos os tabuleiros de grade e interseção destacam automaticamente os destinos legais ao selecionar uma peça.",
      ],
      bulletPoints: [
        "01. Xadrez (chess_game): Inclui roque, captura en passant, detecção de xeque e promoção FIDE para 4 peças.",
        "02. Damas (checkers_game): Captura obrigatória, saltos múltiplos em cadeia e coroação de Dama.",
        "03. Go (go_game): Tabuleiros 9×9, 13×13 e 19×19 com captura BFS de cadeias, proibição de suicídio, Ko e Komi 6.5.",
        "04. Shogi (shogi_game): Tabuleiro 9×9 com reserva de peças capturadas (Komadai), Nifu e promoção FESA.",
        "05. Xiangqi (xiangqi_game): Tabuleiro 9×10 com Rio central, Palácios 3×3, salto de Canhão com tela e General Voador.",
        "06. Damas Chinesas (chinese_checkers_game): Estrela hexagonal de 121 casas com saltos múltiplos em cadeia.",
      ],
    },
    "games-dice-cards-tactical": {
      title: "Jogos 07–14: Dados, Cartas, Combate Naval e Estratégia Global",
      subtitle: "UNO, Jogo da Gansa, Gamão, Ludo, Batalha Naval, Mil Milhas, Monopoly e Crisis/War",
      paragraphs: [
        "Os jogos com dados 3D, cartas ou fases táticas oferecem controles contextuais claros para cada etapa do turno.",
      ],
      bulletPoints: [
        "07. UNO (uno_game): Baralho de 108 cartas, curingas com escolha de cor, penalidades acumuláveis e grito ¡UNO!.",
        "08. Jogo da Gansa (goose_game): Espiral de 63 casas com 13 Gansas, Pontes, Pousada, Poço, Labirinto, Prisão e Caveira.",
        "09. Gamão (backgammon_game): 24 picos, Barra Central, Bear-Off e Cubo de Dobra.",
        "10. Ludo (ludo_game): Cruz 15×15 com 4 bases, 8 estrelas seguras e chegada exata à meta 57.",
        "11. Batalha Naval (battleship_game): Duplo tabuleiro 10×10 com 5 navios ilustrados e Radar de Ataque.",
        "12. Mil Milhas (mille_bornes_game): Rota de 1000 km, 4 escudos de segurança e reação Coup Fourré!.",
        "13. Monopoly (monopoly_game): 40 casas, compra de propriedades, construção uniforme de casas/hotéis e hipotecas.",
        "14. Crisis / War (crisis_game): 30 territórios em 6 continentes, reforços, combate 3v3 com dados e troca de cartas.",
      ],
    },
    "dev-verify-guarantee": {
      title: "Pilar 1. Como Garantir e Auditar que a Aplicação Está 100% Funcional",
      subtitle: "Script de verificação CLI, suítes de testes e Painel de Autodiagnóstico ao vivo",
      paragraphs: [
        "Para garantir a qualquer momento que o cliente Web React + WASM funciona 100%, você dispõe do Centro de Diagnóstico E2E na interface e do script automatizado de terminal.",
        "O script verifica a tipagem TypeScript, todas as suítes de testes dos 14 jogos e 9 idiomas, o build PWA e a documentação.",
      ],
      bulletPoints: [
        "Verificação em um único comando: bash tools/verify_web_client.sh",
        "Execução direta das suítes de regressão: npm --prefix web_client test",
        "Verificação programática: importe runFullSystemDiagnostics() de SystemDiagnosticsPanel.tsx.",
      ],
      codeLabel: "Comandos de Verificação Funcional Completa (Terminal / CI)",
    },
    "dev-architecture-wasm": {
      title: "Pilar 2. Arquitetura React + Ponte Rust WASM e Motor Isomórfico TS",
      subtitle: "Contrato unificado entre open_table_wasm (Rust) e WasmGameBridge (TypeScript)",
      paragraphs: [
        "O cliente Web desacopla a camada visual React da lógica de regras através da classe WasmGameBridge (src/wasm_pkg/index.ts).",
        "Todos os 14 jogos compartilham estado JSON determinístico, gerador de jogadas legais, IA e histórico de replay.",
      ],
      bulletPoints: [
        "start_local_match / start_ai_match: Inicializa a sessão limpa do jogo.",
        "get_state_json() & get_legal_moves_json(player_id): Obtém o estado atual e as jogadas legais.",
        "send_command_json(player_id, cmd_json) & step_ai_if_needed(): Aplica comandos e executa a IA.",
        "export_log_json() & apply_sync_log_json(): Serializa e reconstrói partidas completas.",
      ],
      codeLabel: "Contrato do WasmGameBridge em React / TypeScript",
    },
    "dev-svg-boards-extension": {
      title: "Pilar 3. Guia para Criar ou Estender Tabuleiros SVG e Motores de Jogo",
      subtitle: "Padrão de componentes em src/components/boards/<Game>Board.tsx",
      paragraphs: [
        "Cada um dos 14 jogos possui um componente dedicado em src/components/boards/<Game>Board.tsx recebendo props imutáveis.",
        "Os tabuleiros calculam os destinos válidos a partir de legalMovesJson e disparam comandos via onDispatchCommand.",
      ],
      bulletPoints: [
        "Passo 1: Defina o estado inicial, jogadas legais, redutor de comandos e IA.",
        "Passo 2: Crie o componente SVG responsivo em src/components/boards/.",
        "Passo 3: Registre o jogo em CATALOG_14_GAMES e adicione seu avaliador posicional.",
        "Passo 4: Adicione testes de regressão para auditoria automática no Centro de Diagnóstico.",
      ],
      codeLabel: "Modelo de Componente de Tabuleiro React + SVG",
    },
    "dev-relay-protocol-pwa": {
      title: "Pilar 4. Protocolo WebSocket Relay, Matchmaking ELO e Deploy PWA",
      subtitle: "Interoperabilidade com open_table_relay e pipeline CI/CD para GitHub Pages",
      paragraphs: [
        "RelayWebSocketClient comunica-se com o servidor Rust open_table_relay via quadros JSON tipados e suporta sincronização multi-aba via BroadcastChannel.",
        "O Service Worker da PWA armazena os ativos para que os 14 jogos e a IA funcionem 100% offline.",
      ],
      bulletPoints: [
        "Criar / Entrar / Assistir sala: { action: 'create' }, { action: 'join', code }, { action: 'spectate', code }.",
        "Fila Matchmaking com filtro ELO: { action: 'queue', game_type, elo, max_elo_delta }.",
        "Retransmissão em tempo real de jogadas, estado, ELO e chat da sala.",
      ],
      codeLabel: "Mensagens JSON do Protocolo open_table_relay",
    },
  },
  it: {
    "usage-quickstart": {
      title: "01. Avvio Rapido e Modalità di Partita",
      subtitle: "Hotseat Locale, vs IA Rust (4 livelli), Stanze Online Relay e Spettatore",
      paragraphs: [
        "L'applicazione Web di OpenTable consente di giocare a tutti i 14 giochi da tavolo canonici direttamente nel browser senza configurazione.",
        "Dalla barra superiore puoi passare in qualsiasi momento tra i 14 giochi e scegliere una delle 4 modalità:",
      ],
      bulletPoints: [
        "Hotseat Locale (2 Giocatori): Entrambi i giocatori condividono il dispositivo alternando i turni.",
        "vs IA Rust (4 Livelli): Gioca come Giocatore 1 contro il motore IA deterministico a livello Facile (1000 ELO), Medio (1200 ELO), Difficile (1450 ELO) o Maestro (1700 ELO).",
        "Online Relay / QR: Crea una stanza di 6 caratteri con codice QR istantaneo o unisciti come Giocatore 2.",
        "Modalità Spettatore: Osserva le partite in corso in tempo reale con tabellone in sola lettura e chat.",
      ],
    },
    "usage-matchmaking-elo": {
      title: "02. Coda di Matchmaking Automatico per Fascia ELO",
      subtitle: "Abbinamento competitivo in open_table_relay con espansione progressiva",
      paragraphs: [
        "Nella scheda 'Stanze Online', la Coda di Matchmaking ti abbina a un altro giocatore che cerca lo stesso gioco entro una finestra ELO compatibile.",
        "Il server Relay verifica la condizione simmetrica |ELO_A - ELO_B| <= min(delta_A, delta_B) per garantire partite equilibrate.",
      ],
      bulletPoints: [
        "Seleziona la tolleranza iniziale: ±150 ELO (Stretto), ±300 ELO (Standard) o ±800 ELO (Aperto).",
        "Se non c'è un avversario immediato, la finestra si espande automaticamente ogni 5 secondi.",
        "In qualsiasi momento puoi premere 'Sparring IA Calibrata' per giocare subito contro un'IA adatta al tuo ELO.",
      ],
    },
    "usage-tournaments-elo": {
      title: "03. Organizzatore di Tornei e Classifica ELO K=32",
      subtitle: "Tornei Round-Robin (Tabelle di Berger), Eliminazione Diretta e 12 Obiettivi",
      paragraphs: [
        "La scheda 'Tornei' permette di organizzare competizioni combinando giocatori umani e bot IA in ciascuno dei 14 giochi.",
        "La scheda 'Classifica ELO' mantiene il tuo profilo competitivo con formula ufficiale FIDE K=32 e 12 obiettivi sbloccabili.",
      ],
      bulletPoints: [
        "Girone Round-Robin (Sistema Berger): Tutti contro tutti con classifica automatica.",
        "Eliminazione Diretta (Knockout): Tabellone con avanzamento automatico del vincitore fino alla Finale.",
        "Avvio diretto sul tavolo: Premi 'Gioca sul Tavolo' su qualsiasi incontro in attesa per disputarlo dal vivo.",
      ],
    },
    "usage-analyzer-replay": {
      title: "04. Analizzatore Post-Partita e Visualizzatore Replay",
      subtitle: "Grafico SVG del vantaggio [-100, +100] e classificazione delle mosse",
      paragraphs: [
        "La scheda 'Analizzatore' ricostruisce passo dopo passo qualsiasi partita nei 14 giochi e calcola la curva di vantaggio posizionale.",
        "Inoltre, la barra Replay nel menu laterale permette di scorrere i turni ed esportare o importare file JSON.",
      ],
      bulletPoints: [
        "★ Ottima e ✓ Buona confrontate con il suggerimento dell'IA Maestro (Livello 4).",
        "? Imprecisione e ?? Errore Critico per individuare le svolte tattiche.",
        "Clicca su qualsiasi nodo della curva SVG o riga della tabella per ispezionare il turno e caricarlo sul tavolo.",
      ],
    },
    "usage-accessibility-pwa": {
      title: "05. Orologi da Torneo, Accessibilità Okabe-Ito, Audio e PWA",
      subtitle: "Combo list dei temi visivi, sintesi Web Audio API e gioco 100% offline",
      paragraphs: [
        "Il menu laterale include controlli del tempo ufficiali (Blitz 3+2, Rapido 10+0 e Byo-yomi giapponese), selettore combo list a 3 temi e accessibilità completa.",
      ],
      bulletPoints: [
        "Combo List Temi Visivi: Pietra Scura (predefinito), Notte Blu e Giada Verde.",
        "Modalità Daltonici Okabe-Ito: Sostituisce i colori rosso/verde ambigui con blu (#0072B2) e vermiglio (#D55E00) ad alto contrasto.",
        "Audio Procedurale: Effetti sintetizzati tramite Web Audio API senza file MP3 esterni.",
        "Installazione PWA: Premi 'Installa PWA' nella barra superiore per giocare anche senza connessione internet.",
      ],
    },
    "games-classic-oriental": {
      title: "Giochi 01–06: Strategia Classica e Orientale",
      subtitle: "Scacchi, Dama, Go, Shogi, Xiangqi e Dama Cinese",
      paragraphs: [
        "Tutti i tabelloni evidenziano automaticamente le caselle di destinazione legali quando selezioni un pezzo.",
      ],
      bulletPoints: [
        "01. Scacchi (chess_game): Include arrocco, cattura en passant, rilevamento scacco e promozione FIDE a 4 pezzi.",
        "02. Dama (checkers_game): Presa obbligatoria, salti multipli a catena e promozione a Dama.",
        "03. Go (go_game): Goban 9×9, 13×13 e 19×19 con cattura BFS di catene, divieto di suicidio, regola del Ko e Komi 6.5.",
        "04. Shogi (shogi_game): Scacchiera 9×9 con vassoio dei pezzi catturati (Komadai), Nifu e promozione FESA.",
        "05. Xiangqi (xiangqi_game): Tabellone 9×10 con Fiume centrale, Palazzi 3×3, salto del Cannone con schermo e Generale Volante.",
        "06. Dama Cinese (chinese_checkers_game): Stella esagonale da 121 caselle con salti multipli a catena.",
      ],
    },
    "games-dice-cards-tactical": {
      title: "Giochi 07–14: Dadi, Carte, Combattimento Navale e Strategia Globale",
      subtitle: "UNO, Gioco dell'Oca, Backgammon, Ludo, Battaglia Navale, Mille Miglia, Monopoly e Crisis/Risiko",
      paragraphs: [
        "I giochi con dadi 3D, carte o fasi tattiche mostrano pulsanti contestuali chiari per ogni fase del turno.",
      ],
      bulletPoints: [
        "07. UNO (uno_game): Mazzo da 108 carte, jolly multicolore, penalità cumulabili e chiamata ¡UNO!.",
        "08. Gioco dell'Oca (goose_game): Spirale di 63 caselle con 13 Oche, Ponti, Locanda, Pozzo, Labirinto, Prigione e Teschio.",
        "09. Backgammon (backgammon_game): 24 punte, Barra Centrale, Bear-Off e Cubo del Raddoppio.",
        "10. Ludo (ludo_game): Croce 15×15 con 4 basi, 8 stelle sicure e arrivo esatto al traguardo 57.",
        "11. Battaglia Navale (battleship_game): Doppio tabellone 10×10 con 5 navi illustrate e Radar d'Attacco.",
        "12. Mille Miglia (mille_bornes_game): Percorso di 1000 km, 4 carte sicurezza e reazione Coup Fourré!.",
        "13. Monopoly (monopoly_game): 40 caselle, acquisto proprietà, costruzione uniforme di case/hotel e ipoteche.",
        "14. Crisis / Risiko (crisis_game): 30 territori in 6 continenti, rinforzi, combattimento 3v3 coi dadi e scambio carte.",
      ],
    },
    "dev-verify-guarantee": {
      title: "Pilastro 1. Come Garantire e Verificare il Funzionamento al 100%",
      subtitle: "Script di verifica CLI, suite di test e Pannello di Autodiagnostica dal vivo",
      paragraphs: [
        "Per verificare in ogni momento che il client Web React + WASM funzioni al 100%, sono disponibili sia il Centro di Diagnostica E2E nell'interfaccia sia lo script CLI.",
        "Lo script esegue il controllo TypeScript, tutte le suite di test dei 14 giochi e 9 lingue, la build PWA e la verifica della documentazione.",
      ],
      bulletPoints: [
        "Verifica in un solo comando: bash tools/verify_web_client.sh",
        "Esecuzione diretta dei test di regressione: npm --prefix web_client test",
        "Verifica programmatica: importa runFullSystemDiagnostics() da SystemDiagnosticsPanel.tsx.",
      ],
      codeLabel: "Comandi di Verifica Funzionale Completa (Terminale / CI)",
    },
    "dev-architecture-wasm": {
      title: "Pilastro 2. Architettura React + Bridge Rust WASM e Motore Isomorfico TS",
      subtitle: "Contratto unificato tra open_table_wasm (Rust) e WasmGameBridge (TypeScript)",
      paragraphs: [
        "Il client Web disaccoppia il livello visivo React dalla logica delle regole tramite WasmGameBridge (src/wasm_pkg/index.ts).",
        "Tutti i 14 giochi condividono stato JSON deterministico, generatore di mosse legali, IA e registro di replay.",
      ],
      bulletPoints: [
        "start_local_match / start_ai_match: Inizializza una sessione di gioco pulita.",
        "get_state_json() & get_legal_moves_json(player_id): Restituisce lo stato attuale e le mosse legali.",
        "send_command_json(player_id, cmd_json) & step_ai_if_needed(): Applica i comandi ed esegue l'IA.",
        "export_log_json() & apply_sync_log_json(): Serializza e ricostruisce le partite complete.",
      ],
      codeLabel: "Contratto di WasmGameBridge in React / TypeScript",
    },
    "dev-svg-boards-extension": {
      title: "Pilastro 3. Guida per Creare o Estendere Tabelloni SVG e Motori di Gioco",
      subtitle: "Pattern standard dei componenti in src/components/boards/<Game>Board.tsx",
      paragraphs: [
        "Ciascuno dei 14 giochi ha un componente dedicato in src/components/boards/<Game>Board.tsx che riceve props immutabili.",
        "I tabelloni calcolano le destinazioni valide da legalMovesJson e inviano comandi tramite onDispatchCommand.",
      ],
      bulletPoints: [
        "Passo 1: Definisci stato iniziale, mosse legali, riduttore di comandi e IA.",
        "Passo 2: Crea il componente SVG responsivo in src/components/boards/.",
        "Passo 3: Registra il gioco in CATALOG_14_GAMES e aggiungi il valutatore posizionale.",
        "Passo 4: Aggiungi i test di regressione per l'audit automatico nel Centro di Diagnostica.",
      ],
      codeLabel: "Template di Componente Tabellone React + SVG",
    },
    "dev-relay-protocol-pwa": {
      title: "Pilastro 4. Protocollo WebSocket Relay, Matchmaking ELO e Deploy PWA",
      subtitle: "Interoperabilità con open_table_relay e pipeline CI/CD su GitHub Pages",
      paragraphs: [
        "RelayWebSocketClient comunica con il server Rust open_table_relay tramite frame JSON tipizzati e supporta la sincronizzazione multi-scheda via BroadcastChannel.",
        "Il Service Worker della PWA memorizza nella cache l'applicazione affinché tutti i 14 giochi e l'IA funzionino 100% offline.",
      ],
      bulletPoints: [
        "Crea / Unisciti / Osserva stanza: { action: 'create' }, { action: 'join', code }, { action: 'spectate', code }.",
        "Coda Matchmaking con filtro ELO: { action: 'queue', game_type, elo, max_elo_delta }.",
        "Inoltro in tempo reale di mosse, stato, ELO e chat della stanza.",
      ],
      codeLabel: "Messaggi JSON del Protocollo open_table_relay",
    },
  },
  de: {
    "usage-quickstart": {
      title: "01. Schnellstart & Spielmodi",
      subtitle: "Lokales Hotseat, vs. Rust-KI (4 Stufen), Online-Relay-Räume & Zuschauer",
      paragraphs: [
        "Mit der OpenTable-Webanwendung kannst du alle 14 kanonischen Brettspiele direkt im Browser ohne zusätzliche Einrichtung spielen.",
        "Über die Arbeitsbereich-Symbolleiste kannst du jederzeit zwischen den 14 Spielen wechseln und einen der 4 Modi wählen:",
      ],
      bulletPoints: [
        "Lokales Hotseat (2 Spieler): Beide Spieler teilen sich das Gerät und ziehen abwechselnd am selben Brett.",
        "vs. Rust-KI (4 Stufen): Spiele als Spieler 1 gegen die deterministische KI auf Leicht (1000 ELO), Mittel (1200 ELO), Schwer (1450 ELO) oder Meister (1700 ELO).",
        "Online-Relay / QR: Erstelle einen 6-stelligen Raum mit sofortigem QR-Code oder tritt als Spieler 2 bei.",
        "Zuschauermodus: Verfolge laufende Partien in Echtzeit mit schreibgeschütztem Brett und Raumchat.",
      ],
    },
    "usage-matchmaking-elo": {
      title: "02. Automatische ELO-Matchmaking-Warteschlange",
      subtitle: "Wettkampf-Paarung in open_table_relay mit progressiver Fenstererweiterung",
      paragraphs: [
        "Im Reiter 'Online-Räume' paart dich die automatische Matchmaking-Warteschlange mit einem anderen Spieler innerhalb eines kompatiblen ELO-Fensters.",
        "Der Relay-Server prüft die symmetrische Bedingung |ELO_A - ELO_B| <= min(delta_A, delta_B) für ausgeglichene Partien.",
      ],
      bulletPoints: [
        "Wähle die Starttoleranz: ±150 ELO (Strikt), ±300 ELO (Standard) oder ±800 ELO (Offen).",
        "Wird kein sofortiger Gegner gefunden, erweitert sich das Fenster automatisch alle 5 Sekunden.",
        "Du kannst jederzeit auf 'Kalibriertes KI-Sparring' klicken, um sofort gegen eine auf dein ELO abgestimmte KI zu spielen.",
      ],
    },
    "usage-tournaments-elo": {
      title: "03. Turnier-Manager & ELO K=32 Rangliste",
      subtitle: "Round-Robin-Ligen (Berger-Tabellen), K.-o.-System & 12 Erfolge",
      paragraphs: [
        "Im Reiter 'Turniere' lassen sich Wettbewerbe mit menschlichen Spielern und KI-Bots in jedem der 14 Spiele organisieren.",
        "Der Reiter 'ELO-Rangliste' verwaltet dein dauerhaftes Wettkampfprofil mit offizieller FIDE-K=32-Formel und 12 freischaltbaren Erfolgen.",
      ],
      bulletPoints: [
        "Round-Robin-Liga (Berger-System): Jeder gegen jeden mit automatischer Tabelle.",
        "K.-o.-System (Single Elimination): Turnierbaum mit automatischem Einzug des Siegers ins Finale.",
        "Direktstart am Brett: Klicke bei einer offenen Begegnung auf 'Am Brett Spielen', um sie live auszutragen.",
      ],
    },
    "usage-analyzer-replay": {
      title: "04. Post-Match-Analysator & Replay-Viewer",
      subtitle: "SVG-Vorteilskurve [-100, +100] und Zugqualitätsbewertung",
      paragraphs: [
        "Der Reiter 'Analysator' rekonstruiert jede Partie Schritt für Schritt für alle 14 Spiele und berechnet die Positionsvorteilskurve.",
        "Zusätzlich erlaubt der Replay-Viewer im Seitenmenü das Vor- und Zurückspulen sowie den JSON-Export und -Import.",
      ],
      bulletPoints: [
        "★ Optimal und ✓ Gut im Vergleich zur Empfehlung der Meister-KI (Stufe 4).",
        "? Ungenauigkeit und ?? Kritischer Fehler zur Erkennung taktischer Wendepunkte.",
        "Klicke auf einen Knoten der SVG-Kurve oder eine Tabellenzeile, um den Zugzustand zu prüfen und aufs aktive Brett zu laden.",
      ],
    },
    "usage-accessibility-pwa": {
      title: "05. Turnieruhren, Okabe-Ito-Barrierefreiheit, Audio & PWA",
      subtitle: "Themen-Auswahlliste (Combo List), Web Audio API Synthese & 100 % Offline-Spiel",
      paragraphs: [
        "Das Seitenmenü bietet offizielle Zeitkontrollen (Blitz 3+2, Schnell 10+0 und japanisches Byo-yomi), eine 3-Themen-Auswahlliste und volle Barrierefreiheit.",
      ],
      bulletPoints: [
        "Visuelle Themen (Combo List): Dunkler Stein (Standard), Blaue Nacht und Grüner Jade.",
        "Okabe-Ito-Farbenblindmodus: Ersetzt mehrdeutige Rot/Grün-Paletten durch kontrastreiches Blau (#0072B2) und Zinnoberrot (#D55E00).",
        "Prozedurales Audio: Über die Web Audio API erzeugte Klänge ohne externe MP3-Dateien.",
        "PWA-Installation: Klicke oben auf 'PWA Installieren', um OpenTable lokal zu installieren und komplett offline zu spielen.",
      ],
    },
    "games-classic-oriental": {
      title: "Spiele 01–06: Klassische & Fernöstliche Strategie",
      subtitle: "Schach, Dame, Go, Shogi, Xiangqi & Halma (Sternhalma)",
      paragraphs: [
        "Alle Gitter- und Schnittpunktbretter heben gültige Zielfelder automatisch hervor, sobald du eine eigene Figur auswählst.",
      ],
      bulletPoints: [
        "01. Schach (chess_game): Mit Rochade, En Passant, Schacherkennung und FIDE-4-Figuren-Umwandlung.",
        "02. Dame (checkers_game): Schlagzwang, verkettete Mehrfachsprünge und Damenkrönung.",
        "03. Go (go_game): 9×9-, 13×13- und 19×19-Goban mit BFS-Kettenfang, Selbstmordverbot, Ko-Regel und 6.5 Komi.",
        "04. Shogi (shogi_game): 9×9-Brett mit Figurenbank (Komadai), Nifu-Prüfung und FESA-Beförderung.",
        "05. Xiangqi (xiangqi_game): 9×10-Brett mit Fluss, 3×3-Palästen, Kanonensprung mit Schirm und Fliegendem General.",
        "06. Halma / Chinesische Dame (chinese_checkers_game): 121-Felder-Sternbrett mit verketteten Mehrfachsprüngen.",
      ],
    },
    "games-dice-cards-tactical": {
      title: "Spiele 07–14: Würfel, Karten, Seekampf & Globale Strategie",
      subtitle: "UNO, Gänsespiel, Backgammon, Ludo, Schiffe Versenken, Mille Bornes, Monopoly & Crisis/Risiko",
      paragraphs: [
        "Spiele mit 3D-Würfeln, Kartenhänden oder taktischen Phasen bieten übersichtliche Aktionsschaltflächen für jede Zugphase.",
      ],
      bulletPoints: [
        "07. UNO (uno_game): 108-Karten-Deck, Farbwahl-Joker, stapelbare Strafkarten und ¡UNO!-Ruf.",
        "08. Gänsespiel (goose_game): 63-Felder-Spirale mit 13 Gänsen, Brücken, Herberge, Brunnen, Labyrinth, Gefängnis und Totenkopf.",
        "09. Backgammon (backgammon_game): 24 Zungen, Mittelbar, Bear-Off und Verdopplungswürfel.",
        "10. Ludo (ludo_game): 15×15-Kreuzbrett mit 4 Basen, 8 sicheren Sternfeldern und exaktem Zieleinlauf 57.",
        "11. Schiffe Versenken (battleship_game): Doppeltes 10×10-Raster mit 5 illustrierten Schiffen und Angriffsradar.",
        "12. Mille Bornes (mille_bornes_game): 1000-km-Strecke, 4 Schutzschilde und Coup-Fourré!-Konter.",
        "13. Monopoly (monopoly_game): 40 Felder, Grundstückskauf, gleichmäßiger Haus-/Hotelbau und Hypotheken.",
        "14. Crisis / Risiko (crisis_game): 30 Gebiete auf 6 Kontinenten, Verstärkungen, 3v3-Würfelkampf und Kartentausch.",
      ],
    },
    "dev-verify-guarantee": {
      title: "Säule 1. 100 % Funktionale Einsatzbereitschaft Prüfen & Auditieren",
      subtitle: "CLI-Verifikationsskript, automatisierte Testsuiten & Live-E2E-Diagnosezentrum",
      paragraphs: [
        "Um jederzeit sicherzustellen, dass der React + WASM Web-Client zu 100 % funktioniert, stehen das Live-E2E-Diagnosezentrum und das CLI-Skript bereit.",
        "Das Skript prüft TypeScript-Typen, alle Testsuiten der 14 Spiele und 9 Sprachen, den Vite-Produktionsbuild und die Dokumentation.",
      ],
      bulletPoints: [
        "Ein-Befehl-Verifikation: bash tools/verify_web_client.sh",
        "Direkte Ausführung der Regressionstests: npm --prefix web_client test",
        "Programmatische Prüfung: importiere runFullSystemDiagnostics() aus SystemDiagnosticsPanel.tsx.",
      ],
      codeLabel: "Befehle zur Vollständigen Funktionsprüfung (Terminal / CI)",
    },
    "dev-architecture-wasm": {
      title: "Säule 2. React-Architektur + Rust-WASM-Brücke & Isomorphe TS-Engine",
      subtitle: "Einheitlicher Vertrag zwischen open_table_wasm (Rust) und WasmGameBridge (TypeScript)",
      paragraphs: [
        "Der Web-Client entkoppelt die visuelle React-Schicht über WasmGameBridge (src/wasm_pkg/index.ts) vollständig von der Regellogik.",
        "Alle 14 Spiele teilen sich einen deterministischen JSON-Zustand, Legal-Move-Generator, KI-Stepper und Replay-Logger.",
      ],
      bulletPoints: [
        "start_local_match / start_ai_match: Initialisiert eine saubere Spielsitzung.",
        "get_state_json() & get_legal_moves_json(player_id): Liefert Brettzustand und legale Züge.",
        "send_command_json(player_id, cmd_json) & step_ai_if_needed(): Wendet Befehle an und führt die KI aus.",
        "export_log_json() & apply_sync_log_json(): Serialisiert und rekonstruiert komplette Partien.",
      ],
      codeLabel: "WasmGameBridge-Vertrag in React / TypeScript",
    },
    "dev-svg-boards-extension": {
      title: "Säule 3. Leitfaden zum Erstellen oder Erweitern von SVG-Brettern",
      subtitle: "Standard-Komponentenmuster in src/components/boards/<Game>Board.tsx",
      paragraphs: [
        "Jedes der 14 Spiele besitzt eine eigene Komponente in src/components/boards/<Game>Board.tsx mit unveränderlichen Props.",
        "Bretter berechnen gültige Ziele aus legalMovesJson und senden JSON-Befehle über onDispatchCommand.",
      ],
      bulletPoints: [
        "Schritt 1: Startzustand, legale Züge, Befehls-Reducer und KI definieren.",
        "Schritt 2: Responsives SVG-Brett in src/components/boards/ erstellen.",
        "Schritt 3: Spiel in CATALOG_14_GAMES registrieren und Stellungsbewertung ergänzen.",
        "Schritt 4: Regressionstests hinzufügen, damit das E2E-Diagnosezentrum es automatisch prüft.",
      ],
      codeLabel: "React + SVG-Brettkomponenten-Vorlage",
    },
    "dev-relay-protocol-pwa": {
      title: "Säule 4. Relay-WebSocket-Protokoll, ELO-Matchmaking & PWA-Deployment",
      subtitle: "Interoperabilität mit open_table_relay und CI/CD-Pipeline für GitHub Pages",
      paragraphs: [
        "RelayWebSocketClient kommuniziert über typisierte JSON-Frames mit dem Rust-Server open_table_relay und unterstützt lokales Multi-Tab-BroadcastChannel-Sync.",
        "Der PWA-Service-Worker speichert alle Assets lokal, sodass alle 14 Spiele und die KI zu 100 % offline funktionieren.",
      ],
      bulletPoints: [
        "Raum erstellen / beitreten / zuschauen: { action: 'create' }, { action: 'join', code }, { action: 'spectate', code }.",
        "ELO-Matchmaking-Warteschlange: { action: 'queue', game_type, elo, max_elo_delta }.",
        "Echtzeit-Übertragung von Zügen, Zustand, ELO und Raumchat.",
      ],
      codeLabel: "JSON-Nachrichten des open_table_relay-Protokolls",
    },
  },
  ja: {
    "usage-quickstart": {
      title: "01. クイックスタート＆対局モード",
      subtitle: "ローカルHotseat、vs Rust AI（4段階）、オンラインRelayルーム＆観戦モード",
      paragraphs: [
        "OpenTable Webアプリケーションでは、追加設定なしでブラウザ上から全14種類の公式ボードゲームを直接プレイできます。",
        "ワークスペース上部のバーからいつでも14ゲームを切り替え、4つの対局モードを選択できます：",
      ],
      bulletPoints: [
        "ローカルHotseat（2人対局）：1台のデバイスを共有し、同じ盤面で交互に手番を進めます。",
        "vs Rust AI（4段階）：プレイヤー1として決定論的AIエンジン（初級1000 ELO、中級1200 ELO、上級1450 ELO、マスター1700 ELO）と対戦します。",
        "オンラインRelay / QR：6文字のルームコードと即時QRコードを生成するか、別ブラウザからプレイヤー2として参加します。",
        "観戦モード：進行中の対局を読み取り専用ボードとルームチャット付きでリアルタイム観戦できます。",
      ],
    },
    "usage-matchmaking-elo": {
      title: "02. ELOレート範囲による自動マッチメイキング待機列",
      subtitle: "open_table_relayにおける段階的許容幅拡大付きの競技マッチング",
      paragraphs: [
        "「オンラインルーム」タブの自動マッチメイキング待機列は、同じゲームを近いELO範囲で探している対戦相手と自動マッチングします。",
        "Relayサーバーは対称条件 |ELO_A - ELO_B| <= min(delta_A, delta_B) を検証し、均衡した対局を保証します。",
      ],
      bulletPoints: [
        "初期許容範囲を選択：±150 ELO（厳密）、±300 ELO（標準）、±800 ELO（広範囲）。",
        "対戦相手がすぐに見つからない場合、5秒ごとに許容ウィンドウが自動拡大します。",
        "いつでも「調整済みAIスパーリング」を押すことで、現在のELOに合わせたAIと即座に対局を開始できます。",
      ],
    },
    "usage-tournaments-elo": {
      title: "03. トーナメント運営＆ELO K=32ランキング",
      subtitle: "総当たりリーグ（ベルガー方式）、勝ち抜きトーナメント＆全12実績",
      paragraphs: [
        "「トーナメント」タブでは、全14ゲームで人間プレイヤーとAIボットを組み合わせた大会を主催できます。",
        "「ELOランキング」タブでは、FIDE公式K=32計算式に基づく永続プロフィール、ゲーム別戦績、12種類の解除可能な実績を管理します。",
      ],
      bulletPoints: [
        "総当たり戦（ベルガー方式）：全参加者同士の対戦スケジュールと順位表を自動生成。",
        "勝ち抜き戦（ノックアウト方式）：勝者が自動的に決勝へ進むトーナメント表。",
        "盤面への直接起動：未消化の対戦カードで「盤面で対局」を押すとライブ対局が始まり、結果が大会とELOに自動反映されます。",
      ],
    },
    "usage-analyzer-replay": {
      title: "04. 対局後戦術アナライザー＆リプレイビューア",
      subtitle: "SVG形勢推移グラフ [-100, +100] と着手品質分類",
      paragraphs: [
        "「アナライザー」タブは全14ゲームの対局を1手ずつ再現し、プレイヤー1視点での形勢推移グラフを算出します。",
        "さらにメニュー内のリプレイバーを使って1手ずつの巻き戻し・早送り、JSON出力・読込が可能です。",
      ],
      bulletPoints: [
        "マスターAI（レベル4）の最善手と比較し、★最善手・✓好手を判定。",
        "?疑問手・??悪手（ブランダー）を検出し、勝負の転換点を可視化。",
        "SVGグラフ上のノードや一覧表の行をクリックすると、その局面を検査してアクティブ盤面に読み込めます。",
      ],
    },
    "usage-accessibility-pwa": {
      title: "05. 対局時計、Okabe-Ito色覚多様性対応、音声合成＆PWA",
      subtitle: "テーマ選択コンボリスト、Web Audio API効果音＆100%オフライン対局",
      paragraphs: [
        "メニューには公式持ち時間設定（ブリッツ3+2、ラピッド10+0、囲碁/将棋用の秒読み）、3種類のビジュアルテーマ選択コンボリスト、アクセシビリティ機能が備わっています。",
      ],
      bulletPoints: [
        "ビジュアルテーマ（コンボリスト）：ダークストーン（標準）、ブルーナイト、グリーンジェイド。",
        "Okabe-Ito色覚サポートモード：判別しにくい赤/緑の配色を高コントラストな青（#0072B2）と朱色（#D55E00）に切り替えます。",
        "プロシージャル効果音：外部MP3不要のWeb Audio APIリアルタイム音源合成。",
        "PWAインストール：上部バーの「PWAをインストール」からPCやスマホにインストールし、完全オフラインで対局可能です。",
      ],
    },
    "games-classic-oriental": {
      title: "ゲーム 01–06：古典＆東洋戦略ゲーム",
      subtitle: "チェス、チェッカー、囲碁、将棋、シャンチー（中国象棋）、チャイニーズチェッカー",
      paragraphs: [
        "すべてのグリッド盤および交点盤では、自駒または持ち駒（将棋の駒台）を選択すると合法な移動先が自動的にハイライトされます。",
      ],
      bulletPoints: [
        "01. チェス (chess_game)：キャスリング、アンパッサン、チェック判定、FIDE 4駒種プロモーション対応。",
        "02. チェッカー (checkers_game)：強制捕獲ルール、連続マルチジャンプ、キング昇格対応。",
        "03. 囲碁 (go_game)：9×9 / 13×13 / 19×19路盤、BFS連捕獲、自殺手禁止、コウ判定、コミ6.5目整地対応。",
        "04. 将棋 (shogi_game)：9×9盤と駒台（持ち駒の打ち込み）、二歩チェック、FESA成りルール対応。",
        "05. シャンチー (xiangqi_game)：楚河・漢界の河を持つ9×10盤、3×3九宮、炮の砲架ジャンプ、王不見王ルール対応。",
        "06. チャイニーズチェッカー (chinese_checkers_game)：121マスの六芒星ボードと連続ジャンプ対応。",
      ],
    },
    "games-dice-cards-tactical": {
      title: "ゲーム 07–14：ダイス、カード、海戦＆グローバル戦略",
      subtitle: "UNO、ガチョウのゲーム、バックギャモン、ルド、バトルシップ、ミル・ボーヌ、モノポリー、クライシス",
      paragraphs: [
        "3Dダイスや手札カード、戦術フェーズを持つゲームでは、各ターンの進行に応じた直感的な操作ボタンが表示されます。",
      ],
      bulletPoints: [
        "07. UNO (uno_game)：108枚デッキ、ワイルド色選択、ペナルティ累積、UNOコール対応。",
        "08. ガチョウのゲーム (goose_game)：63マスの螺旋コース、13羽のガチョウ、橋、宿屋、井戸、迷宮、牢獄、ドクロ対応。",
        "09. バックギャモン (backgammon_game)：24ポイント、センターバー、ベアオフ、ダブリングキューブ対応。",
        "10. ルド (ludo_game)：15×15クロスボード、4つの基地、8つの安全スター、57ステップ目のゴール対応。",
        "11. バトルシップ (battleship_game)：5隻のイラスト付き自軍艦隊10×10盤と攻撃レーダー10×10盤。",
        "12. ミル・ボーヌ (mille_bornes_game)：1000 kmレース、4枚の安全シールド、クー・フレ反撃対応。",
        "13. モノポリー (monopoly_game)：40マス周回、物件購入、均等な家・ホテル建設、抵当管理対応。",
        "14. クライシス / リスク (crisis_game)：6大陸30地域、軍隊増援、3v3ダイス戦闘、カード3枚交換対応。",
      ],
    },
    "dev-verify-guarantee": {
      title: "柱1. アプリケーションの100%機能保証と監査方法",
      subtitle: "CLI検証スクリプト、自動テストスイート＆ライブE2E診断センター",
      paragraphs: [
        "React + WASM Webクライアントが100%正常に動作することをいつでも保証するため、UI内のE2E自動診断センターとCLI検証スクリプトの両方を提供しています。",
        "検証スクリプトはTypeScript型チェック、全14ゲームと9言語i18nのテストスイート、Vite本番ビルド、ドキュメント検査を一括実行します。",
      ],
      bulletPoints: [
        "ワンコマンド完全検証：bash tools/verify_web_client.sh",
        "回帰テストスイートの直接実行：npm --prefix web_client test",
        "コードからの診断実行：SystemDiagnosticsPanel.tsx の runFullSystemDiagnostics() を呼び出します。",
      ],
      codeLabel: "完全機能検証コマンド (ターミナル / CI)",
    },
    "dev-architecture-wasm": {
      title: "柱2. Reactアーキテクチャ＋Rust WASMブリッジ＆同型TSエンジン",
      subtitle: "open_table_wasm (Rust) と WasmGameBridge (TypeScript) の統一JSON契約",
      paragraphs: [
        "Webクライアントは WasmGameBridge (src/wasm_pkg/index.ts) によってReactの描画層とルール実行層を完全に分離しています。",
        "全14ゲームが決定論的JSONステート、合法手生成、コマンド適用、AI思考、リプレイ履歴同期を共有します。",
      ],
      bulletPoints: [
        "start_local_match / start_ai_match：クリーンな対局セッションを初期化します。",
        "get_state_json() & get_legal_moves_json(player_id)：現在の盤面状態と合法手リストを取得します。",
        "send_command_json(player_id, cmd_json) & step_ai_if_needed()：コマンドを適用しAI手番を進めます。",
        "export_log_json() & apply_sync_log_json()：リプレイ・解析・Relay同期用に棋譜を直列化・復元します。",
      ],
      codeLabel: "React / TypeScript における WasmGameBridge 契約",
    },
    "dev-svg-boards-extension": {
      title: "柱3. SVGボードコンポーネントとゲームエンジンの拡張ガイド",
      subtitle: "src/components/boards/<Game>Board.tsx の標準コンポーネント設計",
      paragraphs: [
        "14ゲームそれぞれに src/components/boards/<Game>Board.tsx の専用コンポーネントがあり、不変Propsを受け取って描画します。",
        "ボード側で直接状態を書き換えず、legalMovesJson から合法な移動先をハイライトし onDispatchCommand でコマンドを送信します。",
      ],
      bulletPoints: [
        "ステップ1：初期状態、合法手生成、コマンドリデューサー、AIを定義します。",
        "ステップ2：レスポンシブなSVGボードを src/components/boards/ に作成します。",
        "ステップ3：CATALOG_14_GAMES に登録し、形勢評価関数を追加します。",
        "ステップ4：回帰テストを追加し、E2E診断センターで自動監査されるようにします。",
      ],
      codeLabel: "React + SVG ボードコンポーネントのテンプレート",
    },
    "dev-relay-protocol-pwa": {
      title: "柱4. Relay WebSocketプロトコル、ELOマッチメイキング＆PWA配信",
      subtitle: "open_table_relay との相互運用性と GitHub Pages CI/CD パイプライン",
      paragraphs: [
        "RelayWebSocketClient は型付きJSONフレームで Rust製 open_table_relay サーバーと通信し、ローカル環境では BroadcastChannel によるマルチタブ同期にも対応します。",
        "PWA Service Workerがアプリ全体をキャッシュするため、全14ゲームとAIはオフラインでも100%動作します。",
      ],
      bulletPoints: [
        "ルーム作成 / 参加 / 観戦：{ action: 'create' }, { action: 'join', code }, { action: 'spectate', code }。",
        "ELOフィルター付き待機列：{ action: 'queue', game_type, elo, max_elo_delta }。",
        "着手、盤面同期、ELO同期、ルームチャットのリアルタイム中継。",
      ],
      codeLabel: "open_table_relay プロトコルのJSONメッセージ例",
    },
  },
  fr: {
    "usage-quickstart": {
      title: "01. Démarrage Rapide et Modes de Partie",
      subtitle: "Hotseat Local, vs IA Rust (4 niveaux), Salons Online Relais et Spectateur",
      paragraphs: [
        "L'application Web OpenTable permet de jouer aux 14 jeux de société canoniques directement dans le navigateur sans aucune configuration.",
        "Depuis la barre d'outils, vous pouvez basculer à tout moment entre les 14 jeux et choisir l'un des 4 modes :",
      ],
      bulletPoints: [
        "Hotseat Local (2 Joueurs) : Les deux joueurs partagent l'appareil en alternant les tours sur le même plateau.",
        "vs IA Rust (4 Niveaux) : Affrontez le moteur d'IA déterministe en difficulté Facile (1000 ELO), Moyenne (1200 ELO), Difficile (1450 ELO) ou Maître (1700 ELO).",
        "Online Relais / QR : Créez un salon à 6 caractères avec QR code instantané ou rejoignez en tant que Joueur 2.",
        "Mode Spectateur : Observez les parties en cours en temps réel avec plateau en lecture seule et chat du salon.",
      ],
    },
    "usage-matchmaking-elo": {
      title: "02. File de Matchmaking Automatique par Plage ELO",
      subtitle: "Appariement compétitif dans open_table_relay avec élargissement progressif",
      paragraphs: [
        "Dans l'onglet 'Salons Online', la File de Matchmaking vous associe à un autre joueur recherchant le même jeu dans une fenêtre ELO compatible.",
        "Le serveur Relais vérifie la condition symétrique |ELO_A - ELO_B| <= min(delta_A, delta_B) pour garantir des parties équilibrées.",
      ],
      bulletPoints: [
        "Choisissez la tolérance initiale : ±150 ELO (Strict), ±300 ELO (Standard) ou ±800 ELO (Ouvert).",
        "En l'absence d'adversaire immédiat, la fenêtre s'élargit automatiquement toutes les 5 secondes.",
        "À tout moment, cliquez sur 'Sparring IA Calibrée' pour lancer immédiatement une partie contre une IA adaptée à votre ELO.",
      ],
    },
    "usage-tournaments-elo": {
      title: "03. Organisateur de Tournois et Classement ELO K=32",
      subtitle: "Championnats Round-Robin (Tables de Berger), Élimination Directe et 12 Succès",
      paragraphs: [
        "L'onglet 'Tournois' permet d'organiser des compétitions combinant joueurs humains et bots IA sur chacun des 14 jeux.",
        "L'onglet 'Classement ELO' conserve votre profil compétitif avec la formule officielle FIDE K=32 et 12 succès déblocables.",
      ],
      bulletPoints: [
        "Championnat Round-Robin (Système Berger) : Toutes rondes avec classement automatique.",
        "Élimination Directe (Knockout) : Arbre de tournoi avec qualification automatique du vainqueur jusqu'en Finale.",
        "Lancement direct sur le plateau : Cliquez sur 'Jouer sur le Plateau' sur n'importe quelle rencontre en attente pour la disputer en direct.",
      ],
    },
    "usage-analyzer-replay": {
      title: "04. Analyseur d'Après-Partie et Visionneuse de Replay",
      subtitle: "Courbe SVG d'avantage [-100, +100] et qualification des coups",
      paragraphs: [
        "L'onglet 'Analyseur' reconstruit pas à pas toute partie sur les 14 jeux et calcule la courbe d'avantage positionnel du point de vue du Joueur 1.",
        "De plus, la barre de Replay dans le menu latéral permet de reculer ou d'avancer coup par coup et d'exporter/importer en JSON.",
      ],
      bulletPoints: [
        "★ Optimal et ✓ Bon comparés à la recommandation de l'IA Maître (Niveau 4).",
        "? Imprécision et ?? Gaffe critique pour repérer les tournants tactiques.",
        "Cliquez sur n'importe quel nœud de la courbe SVG ou ligne du tableau pour inspecter le tour et le charger sur le plateau actif.",
      ],
    },
    "usage-accessibility-pwa": {
      title: "05. Pendules de Tournoi, Accessibilité Okabe-Ito, Audio et PWA",
      subtitle: "Combo list de thèmes visuels, synthèse Web Audio API et jeu 100 % hors ligne",
      paragraphs: [
        "Le menu latéral intègre des cadences officielles (Blitz 3+2, Rapide 10+0 et Byo-yomi japonais), une liste déroulante de 3 thèmes visuels et une accessibilité complète.",
      ],
      bulletPoints: [
        "Combo List de Thèmes Visuels : Pierre Sombre (par défaut), Nuit Bleue et Jade Vert.",
        "Mode Daltonien Okabe-Ito : Remplace les palettes rouge/vert ambiguës par du bleu (#0072B2) et du vermillon (#D55E00) à fort contraste.",
        "Audio Procédural : Effets synthétisés via Web Audio API sans fichiers MP3 externes.",
        "Installation PWA : Cliquez sur 'Installer PWA' dans l'en-tête pour installer OpenTable et jouer 100 % hors ligne.",
      ],
    },
    "games-classic-oriental": {
      title: "Jeux 01–06 : Stratégie Classique et Orientale",
      subtitle: "Échecs, Dames, Go, Shogi, Xiangqi et Dames Chinoises",
      paragraphs: [
        "Tous les plateaux à grille ou intersections mettent automatiquement en évidence les cases de destination légales lorsqu'une pièce est sélectionnée.",
      ],
      bulletPoints: [
        "01. Échecs (chess_game) : Roque, prise en passant, détection d'échec et promotion FIDE en 4 pièces.",
        "02. Dames (checkers_game) : Prise obligatoire, sauts multiples enchaînés et promotion en Dame.",
        "03. Go (go_game) : Goban 9×9, 13×13 et 19×19 avec capture BFS de chaînes, interdiction du suicide, règle du Ko et Komi 6.5.",
        "04. Shogi (shogi_game) : Plateau 9×9 avec réserve de pièces capturées (Komadai), Nifu et promotion FESA.",
        "05. Xiangqi (xiangqi_game) : Plateau 9×10 avec Rivière centrale, Palais 3×3, saut du Canon avec écran et Général Volant.",
        "06. Dames Chinoises (chinese_checkers_game) : Étoile hexagonale de 121 cases avec sauts multiples en chaîne.",
      ],
    },
    "games-dice-cards-tactical": {
      title: "Jeux 07–14 : Dés, Cartes, Combat Naval et Stratégie Globale",
      subtitle: "UNO, Jeu de l'Oie, Backgammon, Ludo, Bataille Navale, Mille Bornes, Monopoly et Crisis/Risk",
      paragraphs: [
        "Les jeux utilisant des dés 3D, des cartes ou des phases tactiques affichent des boutons contextuels clairs à chaque étape du tour.",
      ],
      bulletPoints: [
        "07. UNO (uno_game) : Paquet de 108 cartes, jokers multicolores, pénalités cumulables et annonce ¡UNO!.",
        "08. Jeu de l'Oie (goose_game) : Spirale de 63 cases avec 13 Oies, Ponts, Hôtel, Puits, Labyrinthe, Prison et Tête de Mort.",
        "09. Backgammon (backgammon_game) : 24 flèches, Barre Centrale, Bear-Off et Videau.",
        "10. Ludo (ludo_game) : Croix 15×15 avec 4 bases, 8 étoiles sûres et arrivée exacte au but 57.",
        "11. Bataille Navale (battleship_game) : Double grille 10×10 avec 5 navires illustrés et Radar d'Attaque.",
        "12. Mille Bornes (mille_bornes_game) : Parcours de 1000 km, 4 Bottes de sécurité et réaction Coup Fourré !.",
        "13. Monopoly (monopoly_game) : 40 cases, achat de terrains, construction uniforme de maisons/hôtels et hypothèques.",
        "14. Crisis / Risk (crisis_game) : 30 territoires sur 6 continents, renforts, combat 3v3 aux dés et échange de cartes.",
      ],
    },
    "dev-verify-guarantee": {
      title: "Pilier 1. Comment Garantir et Auditer le Fonctionnement à 100 %",
      subtitle: "Script de vérification CLI, suites de tests et Centre de Diagnostic E2E en direct",
      paragraphs: [
        "Pour garantir à tout moment que le client Web React + WASM est 100 % opérationnel, vous disposez du Centre de Diagnostic E2E dans l'interface et du script CLI automatisé.",
        "Le script exécute la vérification TypeScript, toutes les suites de tests des 14 jeux et 9 langues, le build PWA Vite et l'audit de documentation.",
      ],
      bulletPoints: [
        "Vérification en une seule commande : bash tools/verify_web_client.sh",
        "Exécution directe des tests de régression : npm --prefix web_client test",
        "Vérification programmatique : importez runFullSystemDiagnostics() depuis SystemDiagnosticsPanel.tsx.",
      ],
      codeLabel: "Commandes de Vérification Fonctionnelle Complète (Terminal / CI)",
    },
    "dev-architecture-wasm": {
      title: "Pilier 2. Architecture React + Pont Rust WASM et Moteur Isomorphe TS",
      subtitle: "Contrat unifié entre open_table_wasm (Rust) et WasmGameBridge (TypeScript)",
      paragraphs: [
        "Le client Web découple totalement la couche visuelle React de la logique des règles via WasmGameBridge (src/wasm_pkg/index.ts).",
        "Les 14 jeux partagent un état JSON déterministe, un générateur de coups légaux, une IA et un historique de replay.",
      ],
      bulletPoints: [
        "start_local_match / start_ai_match : Initialise une session de jeu propre.",
        "get_state_json() & get_legal_moves_json(player_id) : Renvoie l'état du plateau et les coups légaux.",
        "send_command_json(player_id, cmd_json) & step_ai_if_needed() : Applique les commandes et exécute l'IA.",
        "export_log_json() & apply_sync_log_json() : Sérialise et reconstruit les parties complètes.",
      ],
      codeLabel: "Contrat de WasmGameBridge en React / TypeScript",
    },
    "dev-svg-boards-extension": {
      title: "Pilier 3. Guide de Création ou d'Extension des Plateaux SVG",
      subtitle: "Modèle standard de composants dans src/components/boards/<Game>Board.tsx",
      paragraphs: [
        "Chacun des 14 jeux dispose d'un composant dédié dans src/components/boards/<Game>Board.tsx recevant des props immuables.",
        "Les plateaux calculent les destinations valides à partir de legalMovesJson et envoient les commandes via onDispatchCommand.",
      ],
      bulletPoints: [
        "Étape 1 : Définir l'état initial, les coups légaux, le réducteur de commandes et l'IA.",
        "Étape 2 : Créer le composant SVG réactif dans src/components/boards/.",
        "Étape 3 : Enregistrer le jeu dans CATALOG_14_GAMES et ajouter son évaluateur positionnel.",
        "Étape 4 : Ajouter ses tests de régression pour l'audit automatique dans le Centre de Diagnostic.",
      ],
      codeLabel: "Modèle de Composant de Plateau React + SVG",
    },
    "dev-relay-protocol-pwa": {
      title: "Pilier 4. Protocole WebSocket Relais, Matchmaking ELO et Déploiement PWA",
      subtitle: "Interopérabilité avec open_table_relay et pipeline CI/CD vers GitHub Pages",
      paragraphs: [
        "RelayWebSocketClient communique avec le serveur Rust open_table_relay via des trames JSON typées et prend en charge la synchronisation multi-onglets via BroadcastChannel.",
        "Le Service Worker de la PWA met en cache l'application pour que les 14 jeux et l'IA fonctionnent 100 % hors ligne.",
      ],
      bulletPoints: [
        "Créer / Rejoindre / Observer un salon : { action: 'create' }, { action: 'join', code }, { action: 'spectate', code }.",
        "File Matchmaking avec filtre ELO : { action: 'queue', game_type, elo, max_elo_delta }.",
        "Retransmission en temps réel des coups, de l'état, de l'ELO et du chat.",
      ],
      codeLabel: "Messages JSON du Protocole open_table_relay",
    },
  },
  ko: {
    "usage-quickstart": {
      title: "01. 빠른 시작 및 대국 모드",
      subtitle: "로컬 Hotseat, vs Rust AI (4단계), 온라인 Relay 방 및 관전 모드",
      paragraphs: [
        "OpenTable 웹 애플리케이션은 별도의 설치 없이 브라우저에서 14종의 공식 보드게임을 즉시 플레이할 수 있습니다.",
        "작업 공간 상단 바에서 언제든지 14개 게임을 전환하고 4가지 운영 모드 중 하나를 선택할 수 있습니다:",
      ],
      bulletPoints: [
        "로컬 Hotseat (2인용): 두 플레이어가 기기를 공유하며 같은 보드에서 번갈아 차례를 진행합니다.",
        "vs Rust AI (4단계): 플레이어 1로서 결정론적 AI 엔진(쉬움 1000 ELO, 보통 1200 ELO, 어려움 1450 ELO, 마스터 1700 ELO)과 대국합니다.",
        "온라인 Relay / QR: 즉시 QR 코드가 포함된 6자리 방을 생성하거나 다른 브라우저에서 플레이어 2로 참가합니다.",
        "관전 모드: 읽기 전용 보드와 실시간 방 채팅을 통해 진행 중인 대국을 실시간으로 관전합니다.",
      ],
    },
    "usage-matchmaking-elo": {
      title: "02. ELO 범위 기반 자동 매치메이킹 대기열",
      subtitle: "점진적 허용 범위 확장을 지원하는 open_table_relay 경쟁 매칭",
      paragraphs: [
        "'온라인 방' 탭의 자동 매치메이킹 대기열은 호환되는 ELO 범위 내에서 동일한 게임을 찾는 상대와 자동으로 매칭해 줍니다.",
        "Relay 서버는 균형 잡힌 대국을 위해 대칭 조건 |ELO_A - ELO_B| <= min(delta_A, delta_B)를 검증합니다.",
      ],
      bulletPoints: [
        "초기 허용 범위 선택: ±150 ELO (엄격), ±300 ELO (표준), ±800 ELO (개방).",
        "즉시 매칭되는 상대가 없으면 5초마다 허용 범위가 자동으로 확장됩니다.",
        "언제든지 '맞춤형 AI 스파링' 버튼을 눌러 현재 ELO에 맞춘 AI와 즉시 대국을 시작할 수 있습니다.",
      ],
    },
    "usage-tournaments-elo": {
      title: "03. 토너먼트 매니저 및 ELO K=32 랭킹",
      subtitle: "라운드 로빈 리그(베르거 테이블), 싱글 엘리미네이션 및 12개 업적",
      paragraphs: [
        "'토너먼트' 탭에서는 14개 모든 게임에서 인간 플레이어와 AI 봇을 조합해 대회를 개최할 수 있습니다.",
        "'ELO 랭킹' 탭은 공식 FIDE K=32 공식을 적용한 영구 경쟁 프로필, 게임별 통계 및 12가지 달성 가능한 업적을 관리합니다.",
      ],
      bulletPoints: [
        "라운드 로빈 리그(베르거 방식): 풀리그 대진표 및 실시간 순위표 자동 생성.",
        "싱글 엘리미네이션(토너먼트): 승자가 자동으로 결승까지 진출하는 대진표.",
        "보드로 즉시 실행: 대기 중인 경기에서 '보드에서 대국'을 누르면 실시간 대국이 시작되며 결과가 토너먼트와 ELO에 자동 반영됩니다.",
      ],
    },
    "usage-analyzer-replay": {
      title: "04. 대국 후 전술 분석기 및 리플레이 뷰어",
      subtitle: "SVG 형세 유불리 곡선 [-100, +100] 및 착수 품질 분류",
      paragraphs: [
        "'분석기' 탭은 14개 모든 게임의 대국을 한 수씩 재구성하고 플레이어 1 관점의 형세 유불리 곡선을 계산합니다.",
        "또한 메뉴 서랍의 리플레이 바를 통해 턴별 되감기/빨리감기 및 JSON 내보내기/가져오기를 수행할 수 있습니다.",
      ],
      bulletPoints: [
        "마스터 AI(레벨 4) 추천 수와 비교하여 ★ 최적수 및 ✓ 호수 판정.",
        "? 부정확한 수 및 ?? 치명적 실수(블런더)를 감지하여 승부처를 시각화.",
        "SVG 곡선의 노드나 표의 행을 클릭하여 해당 턴의 정확한 상태를 검사하고 활성 보드에 불러올 수 있습니다.",
      ],
    },
    "usage-accessibility-pwa": {
      title: "05. 토너먼트 시계, Okabe-Ito 색각 접근성, 오디오 및 PWA",
      subtitle: "테마 콤보 리스트, Web Audio API 사운드 합성 및 100% 오프라인 플레이",
      paragraphs: [
        "메뉴 서랍에는 공식 시간 제한(블리츠 3+2, 래피드 10+0, 바둑/쇼기용 초읽기), 3가지 테마 콤보 리스트 및 완벽한 접근성 기능이 포함되어 있습니다.",
      ],
      bulletPoints: [
        "비주얼 테마 콤보 리스트: 다크 스톤(기본), 블루 나이트, 그린 제이드.",
        "Okabe-Ito 색맹 지원 모드: 구분하기 어려운 적/녹 색상을 고대비 파란색(#0072B2)과 주홍색(#D55E00)으로 대체합니다.",
        "절차적 오디오: 외부 MP3 파일 없이 Web Audio API로 실시간 합성되는 효과음.",
        "PWA 설치: 상단 바의 'PWA 설치'를 눌러 데스크톱이나 모바일에 설치하고 인터넷 없이 100% 오프라인으로 플레이하세요.",
      ],
    },
    "games-classic-oriental": {
      title: "게임 01–06: 클래식 및 동양 전략 게임",
      subtitle: "체스, 체커, 바둑, 쇼기, 샹치 및 차이니즈 체커",
      paragraphs: [
        "모든 격자 및 교차점 보드는 자신의 기물이나 포획한 기물(쇼기의 코마다이)을 선택하면 이동 가능한 칸을 자동으로 강조 표시합니다.",
      ],
      bulletPoints: [
        "01. 체스 (chess_game): 캐슬링, 앙파상, 체크 감지 및 FIDE 4종 기물 승진 지원.",
        "02. 체커 (checkers_game): 강제 포획, 연속 다중 점프 및 킹 승격 지원.",
        "03. 바둑 (go_game): 9×9, 13×13, 19×19 바둑판, BFS 연쇄 따내기, 자살수 금지, 패(Ko) 규칙 및 덤 6.5집 계가 지원.",
        "04. 쇼기 (shogi_game): 9×9 보드와 코마다이(기물 재투입), 니후(이보) 검증 및 FESA 승격 지원.",
        "05. 샹치 (xiangqi_game): 초하/한계 강이 있는 9×10 보드, 3×3 궁성, 포의 다리 점프 및 비장 규칙 지원.",
        "06. 차이니즈 체커 (chinese_checkers_game): 121칸 육각별 보드와 연속 다중 점프 지원.",
      ],
    },
    "games-dice-cards-tactical": {
      title: "게임 07–14: 주사위, 카드, 해전 및 글로벌 전략",
      subtitle: "UNO, 거위 게임, 백개먼, 루도, 배틀쉽, 밀 보른, 모노폴리 및 크라이시스",
      paragraphs: [
        "3D 주사위, 카드 패 또는 전술 단계가 있는 게임은 각 턴 단계에 맞는 명확한 컨텍스트 버튼을 제공합니다.",
      ],
      bulletPoints: [
        "07. UNO (uno_game): 108장 덱, 와일드 색상 선택, 벌칙 누적 및 UNO! 외치기.",
        "08. 거위 게임 (goose_game): 63칸 나선형 트랙, 13개의 거위 칸, 다리, 여관, 우물, 미로, 감옥 및 해골.",
        "09. 백개먼 (backgammon_game): 24개 포인트, 중앙 바, 베어오프 및 더블링 큐브.",
        "10. 루도 (ludo_game): 15×15 십자 보드, 4개 기지, 8개 안전 별 칸 및 57번 골인 지점.",
        "11. 배틀쉽 (battleship_game): 5척의 일러스트 함선이 배치된 아군 10×10 보드와 공격 레이더 10×10 보드.",
        "12. 밀 보른 (mille_bornes_game): 1000 km 주행 코스, 4장의 안전 방패 및 쿠 푸레! 반격.",
        "13. 모노폴리 (monopoly_game): 40칸 보드, 부동산 매입, 균등한 집/호텔 건설 및 저당권 관리.",
        "14. 크라이시스 / 리스크 (crisis_game): 6개 대륙 30개 영토, 병력 증원, 3v3 주사위 전투 및 카드 3장 교환.",
      ],
    },
    "dev-verify-guarantee": {
      title: "핵심 1. 애플리케이션 100% 기능 보증 및 감사 방법",
      subtitle: "CLI 검증 스크립트, 자동화 테스트 스위트 및 실시간 E2E 진단 센터",
      paragraphs: [
        "React + WASM 웹 클라이언트가 언제나 100% 정상 작동하는지 확인하기 위해 UI 내 실시간 E2E 진단 센터와 터미널 자동 검증 스크립트를 모두 제공합니다.",
        "검증 스크립트는 TypeScript 정적 타입 검사, 14개 게임 및 9개 언어 i18n 테스트 스위트, Vite 프로덕션 빌드 및 문서 검사를 실행합니다.",
      ],
      bulletPoints: [
        "단일 명령어로 전체 검증: bash tools/verify_web_client.sh",
        "회귀 테스트 스위트 직접 실행: npm --prefix web_client test",
        "코드 내 프로그래밍 방식 검증: SystemDiagnosticsPanel.tsx에서 runFullSystemDiagnostics()를 가져와 호출합니다.",
      ],
      codeLabel: "전체 기능 검증 명령어 (터미널 / CI)",
    },
    "dev-architecture-wasm": {
      title: "핵심 2. React 아키텍처 + Rust WASM 브리지 및 동형 TS 엔진",
      subtitle: "open_table_wasm (Rust)과 WasmGameBridge (TypeScript) 간의 통합 JSON 계약",
      paragraphs: [
        "웹 클라이언트는 WasmGameBridge (src/wasm_pkg/index.ts)를 통해 React 시각 계층과 규칙 실행 로직을 완전히 분리합니다.",
        "14개 모든 게임이 결정론적 JSON 상태, 합법수 생성기, 명령 리듀서, AI 실행기 및 리플레이 로그 직렬화를 공유합니다.",
      ],
      bulletPoints: [
        "start_local_match / start_ai_match: 깨끗한 대국 세션을 초기화합니다.",
        "get_state_json() & get_legal_moves_json(player_id): 현재 보드 상태와 합법수 목록을 반환합니다.",
        "send_command_json(player_id, cmd_json) & step_ai_if_needed(): 명령을 적용하고 AI 턴을 실행합니다.",
        "export_log_json() & apply_sync_log_json(): 리플레이, 분석기 및 Relay 동기화를 위해 대국 기록을 직렬화/복원합니다.",
      ],
      codeLabel: "React / TypeScript의 WasmGameBridge 계약",
    },
    "dev-svg-boards-extension": {
      title: "핵심 3. SVG 보드 컴포넌트 및 게임 엔진 확장 가이드",
      subtitle: "src/components/boards/<Game>Board.tsx의 표준 컴포넌트 패턴",
      paragraphs: [
        "14개 게임 각각은 src/components/boards/<Game>Board.tsx에 전용 컴포넌트를 가지며 불변 Props를 전달받습니다.",
        "보드는 로컬에서 상태를 직접 변경하지 않고 legalMovesJson으로 유효 목적지를 강조하며 onDispatchCommand로 명령을 전송합니다.",
      ],
      bulletPoints: [
        "1단계: 초기 상태, 합법수 생성기, 명령 리듀서 및 AI를 정의합니다.",
        "2단계: src/components/boards/에 반응형 SVG 보드 컴포넌트를 생성합니다.",
        "3단계: CATALOG_14_GAMES에 게임을 등록하고 형세 평가 함수를 추가합니다.",
        "4단계: E2E 진단 센터에서 자동으로 감사하도록 회귀 테스트를 추가합니다.",
      ],
      codeLabel: "React + SVG 보드 컴포넌트 템플릿",
    },
    "dev-relay-protocol-pwa": {
      title: "핵심 4. Relay WebSocket 프로토콜, ELO 매치메이킹 및 PWA 배포",
      subtitle: "open_table_relay 상호운용성 및 GitHub Pages CI/CD 파이프라인",
      paragraphs: [
        "RelayWebSocketClient는 타입화된 JSON 프레임으로 Rust open_table_relay 서버와 통신하며 로컬 멀티탭 BroadcastChannel 동기화를 지원합니다.",
        "PWA 서비스 워커가 애플리케이션 전체를 캐싱하므로 14개 모든 게임과 AI가 100% 오프라인으로 작동합니다.",
      ],
      bulletPoints: [
        "방 생성 / 참가 / 관전: { action: 'create' }, { action: 'join', code }, { action: 'spectate', code }.",
        "ELO 필터 매치메이킹 대기열: { action: 'queue', game_type, elo, max_elo_delta }.",
        "착수, 상태 동기화, ELO 동기화 및 방 채팅의 실시간 중계.",
      ],
      codeLabel: "open_table_relay 프로토콜 JSON 메시지",
    },
  },
  zh: {
    "usage-quickstart": {
      title: "01. 快速上手与对局模式",
      subtitle: "本地同屏 (Hotseat)、迎战 Rust AI（4个等级）、在线 Relay 房间与观战模式",
      paragraphs: [
        "OpenTable Web 应用支持直接在浏览器中畅玩全部 14 款标准桌面游戏，无需任何额外配置。",
        "通过工作区顶部工具栏，你可以随时在 14 款游戏之间切换，并选择 4 种运行模式之一：",
      ],
      bulletPoints: [
        "本地同屏 (2名玩家)：两名玩家共用同一台设备，在同一棋盘上轮流落子。",
        "迎战 Rust AI (4个等级)：作为玩家 1 挑战确定性 AI 引擎，支持简单 (1000 ELO)、中等 (1200 ELO)、困难 (1450 ELO) 与大师 (1700 ELO)。",
        "在线 Relay / 二维码：创建带即时二维码的 6 位房间码，或从另一浏览器作为玩家 2 加入。",
        "观战模式：以只读棋盘和实时房间聊天观看正在进行的对局。",
      ],
    },
    "usage-matchmaking-elo": {
      title: "02. 基于 ELO 分数段的自动匹配队列",
      subtitle: "open_table_relay 中支持渐进式窗口扩大的竞技匹配",
      paragraphs: [
        "在“在线房间”标签页中，自动匹配队列会将你与正在寻找同一款游戏且 ELO 范围兼容的对手自动配对。",
        "Relay 服务器验证对称条件 |ELO_A - ELO_B| <= min(delta_A, delta_B) 以确保对局势均力敌。",
      ],
      bulletPoints: [
        "选择初始容差范围：±150 ELO（严格）、±300 ELO（标准）或 ±800 ELO（开放）。",
        "若未立即找到对手，匹配窗口会每 5 秒自动扩大一次。",
        "你随时可以点击“校准 AI 陪练”，立即与匹配你当前 ELO 的 AI 开始对局。",
      ],
    },
    "usage-tournaments-elo": {
      title: "03. 锦标赛管理器与 ELO K=32 排名",
      subtitle: "循环赛（贝格尔编排表）、单败淘汰赛与 12 项成就",
      paragraphs: [
        "“锦标赛”标签页支持在任意一款游戏中组织人类玩家与 AI 机器人混合参赛的锦标赛。",
        "“ELO 排名”标签页采用官方 FIDE K=32 公式维护你的持久化竞技档案、分项统计及 12 项可解锁成就。",
      ],
      bulletPoints: [
        "循环赛（贝格尔系统）：全员循环对阵并自动计算积分榜。",
        "单败淘汰赛（Knockout）：胜者自动晋级直至总决赛的对阵树。",
        "直接进入棋盘对局：在任意待赛场次点击“在棋盘上对局”即可实时开赛，赛果会自动写入锦标赛与 ELO 档案。",
      ],
    },
    "usage-analyzer-replay": {
      title: "04. 赛后战术复盘分析器与回放查看器",
      subtitle: "SVG 局势优势曲线 [-100, +100] 与着法质量评级",
      paragraphs: [
        "“分析器”标签页可逐步重建全部 14 款游戏的任意对局，并从玩家 1 视角计算局势优势曲线。",
        "此外，侧边菜单中的回放进度条支持逐回合快退/快进，以及导出或导入 JSON 对局记录。",
      ],
      bulletPoints: [
        "与大师级 AI（等级 4）推荐路线对比，评定 ★ 最佳与 ✓ 良好着法。",
        "识别 ? 不精确与 ?? 严重失误（Blunder），直观呈现关键转折点。",
        "点击 SVG 曲线上的任意节点或表格行，即可检查该回合的精确局面并将其加载到当前棋盘。",
      ],
    },
    "usage-accessibility-pwa": {
      title: "05. 锦标赛计时器、Okabe-Ito 色觉无障碍、音效与 PWA",
      subtitle: "视觉主题下拉列表 (Combo List)、Web Audio API 音效合成与 100% 离线畅玩",
      paragraphs: [
        "侧边菜单包含官方计时制（超快棋 3+2、快棋 10+0 及围棋/将棋读秒 Byo-yomi）、3 款视觉主题下拉框及全面无障碍支持。",
      ],
      bulletPoints: [
        "视觉主题下拉框 (Combo List)：深色玄石（默认）、深邃蓝夜与翡翠玉石。",
        "Okabe-Ito 色盲友好模式：将易混淆的红/绿配色替换为高对比度蓝色 (#0072B2) 与朱红色 (#D55E00)。",
        "程序化合成音效：基于 Web Audio API 实时合成落子、骰子、卡牌、胜利与读秒提示音，无需外部 MP3。",
        "PWA 安装：点击顶部栏的“安装 PWA”将 OpenTable 安装至桌面或手机，无网络也能 100% 离线游玩。",
      ],
    },
    "games-classic-oriental": {
      title: "游戏 01–06：经典与东方策略棋类",
      subtitle: "国际象棋、西洋跳棋、围棋、日本将棋、中国象棋与中国跳棋",
      paragraphs: [
        "所有网格与交叉点棋盘在选中己方棋子或持驹（将棋驹台）时，都会自动高亮显示所有合法的目标位置。",
      ],
      bulletPoints: [
        "01. 国际象棋 (chess_game)：支持王车易位、吃过路兵、将军检测与 FIDE 四子升变。",
        "02. 西洋跳棋 (checkers_game)：强制吃子、连续多步跳吃与王棋加冕。",
        "03. 围棋 (go_game)：9×9、13×13 与 19×19 棋盘，支持 BFS 棋链提子、禁自杀、劫争检测与贴 6.5 目点目。",
        "04. 日本将棋 (shogi_game)：9×9 棋盘配驹台持驹打入、二步禁手校验与 FESA 升变。",
        "05. 中国象棋 (xiangqi_game)：9×10 楚河汉界棋盘、3×3 九宫、炮隔山打牛与飞将禁手。",
        "06. 中国跳棋 (chinese_checkers_game)：121 孔六角星形棋盘与长距离连续跳子。",
      ],
    },
    "games-dice-cards-tactical": {
      title: "游戏 07–14：骰子、卡牌、海战与全球战略",
      subtitle: "UNO、鹅棋、双陆棋、飞行棋、海战棋、千里之行、大富翁与全球危机",
      paragraphs: [
        "带有 3D 骰子、手牌或战术阶段的游戏会在每个回合阶段提供清晰的上下文操作按钮。",
      ],
      bulletPoints: [
        "07. UNO (uno_game)：108 张牌组、万能牌选色、罚牌叠加与 ¡UNO! 喊牌。",
        "08. 鹅棋 (goose_game)：63 格螺旋赛道，包含 13 个鹅格、桥梁、客栈、水井、迷宫、监狱与骷髅。",
        "09. 双陆棋 (backgammon_game)：24 个三角点、中央栏、Bear-Off 离盘与加倍方块。",
        "10. 飞行棋 (ludo_game)：15×15 十字棋盘、4 个基地、8 个安全星格与第 57 格精确终点。",
        "11. 海战棋 (battleship_game)：双 10×10 海域网格，含己方 5 艘插画战舰与敌方攻击雷达。",
        "12. 千里之行 (mille_bornes_game)：1000 公里赛程、4 张王牌护盾与 Coup Fourré! 瞬间反击。",
        "13. 大富翁 (monopoly_game)：40 格地产棋盘、买地建房、均匀升级旅馆与抵押管理。",
        "14. 全球危机 / 战地风云 (crisis_game)：6 大洲 30 个领土、兵力增援、3v3 骰子会战与三卡兑换。",
      ],
    },
    "dev-verify-guarantee": {
      title: "支柱 1. 如何确保并审计应用 100% 功能完好",
      subtitle: "CLI 验证脚本、自动化测试套件与实时 E2E 诊断中心",
      paragraphs: [
        "为随时确保 React + WASM Web 客户端 100% 正常运行，系统同时提供了界面内的 E2E 诊断中心和终端自动化验证脚本。",
        "验证脚本会自动执行 TypeScript 静态类型检查、全部 14 款游戏与 9 种语言 i18n 测试套件、Vite 生产构建以及文档审计。",
      ],
      bulletPoints: [
        "单条命令完整验证：bash tools/verify_web_client.sh",
        "直接运行回归测试套件：npm --prefix web_client test",
        "代码中编程调用验证：从 SystemDiagnosticsPanel.tsx 导入并调用 runFullSystemDiagnostics()。",
      ],
      codeLabel: "完整功能验证命令（终端 / CI）",
    },
    "dev-architecture-wasm": {
      title: "支柱 2. React 架构 + Rust WASM 桥接与同构 TS 引擎",
      subtitle: "open_table_wasm (Rust) 与 WasmGameBridge (TypeScript) 的统一 JSON 契约",
      paragraphs: [
        "Web 客户端通过 WasmGameBridge (src/wasm_pkg/index.ts) 将 React 视图层与规则逻辑完全解耦。",
        "全部 14 款游戏共享确定性 JSON 状态、合法着法生成器、指令归约器、AI 步进器与回放日志序列化。",
      ],
      bulletPoints: [
        "start_local_match / start_ai_match：初始化干净的对局会话。",
        "get_state_json() & get_legal_moves_json(player_id)：返回当前棋盘快照与合法着法列表。",
        "send_command_json(player_id, cmd_json) & step_ai_if_needed()：执行玩家指令并推进 AI 回合。",
        "export_log_json() & apply_sync_log_json()：序列化并重建完整对局，用于回放、分析器与 Relay 同步。",
      ],
      codeLabel: "React / TypeScript 中的 WasmGameBridge 契约",
    },
    "dev-svg-boards-extension": {
      title: "支柱 3. 创建或扩展 SVG 棋盘组件与游戏引擎指南",
      subtitle: "src/components/boards/<Game>Board.tsx 的标准组件模式",
      paragraphs: [
        "14 款游戏在 src/components/boards/<Game>Board.tsx 中各有独立组件，接收不可变 Props 进行渲染。",
        "棋盘组件不在本地直接修改状态，而是根据 legalMovesJson 高亮有效目标，并通过 onDispatchCommand 发送指令。",
      ],
      bulletPoints: [
        "步骤 1：定义初始状态、合法着法生成器、指令归约器与 AI。",
        "步骤 2：在 src/components/boards/ 下创建响应式 SVG 棋盘组件。",
        "步骤 3：在 CATALOG_14_GAMES 中注册游戏并添加局势评估函数。",
        "步骤 4：添加回归测试，使 E2E 诊断中心能够自动对其进行审计。",
      ],
      codeLabel: "React + SVG 棋盘组件模板",
    },
    "dev-relay-protocol-pwa": {
      title: "支柱 4. Relay WebSocket 协议、ELO 匹配与 PWA 部署",
      subtitle: "与 open_table_relay 的互操作性及 GitHub Pages CI/CD 流水线",
      paragraphs: [
        "RelayWebSocketClient 使用类型化 JSON 帧与 Rust open_table_relay 服务器通信，并在本地支持基于 BroadcastChannel 的多标签页同步。",
        "PWA Service Worker 会缓存全部应用资源，使 14 款游戏和 AI 在无网络时也能 100% 离线运行。",
      ],
      bulletPoints: [
        "创建 / 加入 / 观战房间：{ action: 'create' }, { action: 'join', code }, { action: 'spectate', code }。",
        "带 ELO 过滤的匹配队列：{ action: 'queue', game_type, elo, max_elo_delta }。",
        "实时转发着法指令、状态同步、ELO 同步与房间聊天。",
      ],
      codeLabel: "open_table_relay 协议 JSON 消息示例",
    },
  },
};

export function getLocalizedDocumentationSections(
  locale: SupportedLocale,
  baseSections: DocumentationSection[]
): DocumentationSection[] {
  if (locale === "es") return baseSections;
  const overrides = DOC_SECTIONS_BY_LOCALE[locale];
  if (!overrides) return baseSections;

  return baseSections.map((sec) => {
    const locSec = overrides[sec.id];
    if (!locSec) return sec;
    return {
      ...sec,
      title: locSec.title,
      subtitle: locSec.subtitle,
      paragraphs: locSec.paragraphs,
      bulletPoints: locSec.bulletPoints ?? sec.bulletPoints,
      codeSnippet: sec.codeSnippet
        ? {
            label: locSec.codeLabel || sec.codeSnippet.label,
            code: sec.codeSnippet.code,
          }
        : undefined,
    };
  });
}
