# Game Design Document (GDD) — BLOODSURGE

> **Título Oficial:** BLOODSURGE  
> **Subtítulo:** High-Speed Adrenaline Movement Shooter  
> **Gênero:** Retro Movement FPS / Boomer Shooter  
> **Inspirações:** *Ultrakill*, *Doom (1993/2016)*, *Dusk*, *Quake*  
> **Engine:** Godot Engine 4.7  
> **Pipeline Visual:** Low-Poly Estilizado / Retro Crunchy Shaders + Blender MCP  
> **Trilha Sonora:** Heavy Metal Industrial / Djent / Synth-Metal (140-160 BPM)  

---

## 1. Visão Geral & Filosofia de Jogo
**"O movimento é sua única armadura. O sangue inimigo é seu combustível."**

**BLOODSURGE** é um jogo de tiro em primeira pessoa focado em reflexos instantâneos, mobilidade acrobática, mira precisa e agressividade constante. O jogador não recua e não busca cobertura: toda mecânica de sobrevivência depende de avançar com velocidade contra os inimigos e estraçalhá-los à queima-roupa.

---

## 2. Pilares de Design

1. **Velocidade & Cinestesia (Game Feel):**
   * Movimentação base de 11 m/s, resposta imediata sem desaceleração frouxa.
   * Dash omnidirecional no `Shift` com recarga rápida por cargas (3 charges).
   * Slide no `Ctrl` que rasga o chão com faíscas e mantém a inércia em alta velocidade.
   * Controle aéreo responsivo (*Air-strafing*).

2. **O "Soco" da Arma (Visceral Shooting):**
   * Mira manual no mouse sem auxílio ou autocorreção.
   * Super Shotgun de cano duplo com recuo visual vigoroso da câmera.
   * Hitstop (*micro-freeze*) de 50ms quando tiros eliminam alvos de perto.
   * Hitmarker auditivo com estalo mecânico afiado (*CRUNCH/DING*).

3. **Mecânica Central: Blood Siphon (O Sangue Cura):**
   * Dano ou eliminação a curta distância (< 4.5 metros) lança jorros de sangue absorvidos pelo jogador.
   * Esse sangue restaura o HP instantaneamente, recompensando jogadas ousadas na cara do inimigo.

4. **Trilha Sonora Heavy Rock / Djent / Metal:**
   * Batidas de bumbo duplo aceleradas e guitarras pesadas de 8 cordas afinadas em Drop E/F.
   * Ducking dinâmico: o tiro de shotgun comprime levemente o áudio da música para soar como um trovão.

---

## 3. Controles Padrão (PC)

| Entrada | Ação | Descrição |
| :--- | :--- | :--- |
| `W, A, S, D` | Mover | Movimentação em 8 direções (11 m/s) |
| `Mouse` | Olhar / Mirar | Rotação livre de câmera sem aceleração |
| `Espaço` | Pular | Pulo ágil e salto duplo vertical |
| `Shift` | Dash | Esquiva direcional instantânea com onda de choque visual |
| `Ctrl` | Slide | Deslizar rente ao solo com aumento temporário de velocidade (até 28 m/s) |
| `1, 2 / Q / Wheel` | Trocar Arma | Alternar entre Super Shotgun e Piercer Revolver |
| `Botão Esquerdo (LMB)` | Disparo Primário | Disparo de shotgun ou tiro de precisão do revólver |
| `Botão Direito (RMB)` | Disparo Alternativo | Tiro duplo de shotgun ou carregar Feixe Perfurante |
| `F` | Soco Melee / Parry | Soco de impacto e deflexão de projéteis com cura instantânea |
| `R` | Reiniciar / Recarregar | Reinício instantâneo ao morrer ou recarga de cartuchos |
| `ESC` | Pausar | Menu do sistema durante a partida |

---

## 4. Arsenal do Jogador

* **Slot 1 — Super Shotgun:** Cano duplo serrado, 10 balins de chumbo com dispersão ampla, alto recuo e estrondo ensurdecedor. RMB dispara tiro duplo concentrado. Essencial para o *Blood Siphon* à queima-roupa.
* **Slot 2 — Piercer Revolver:** Canhão de mão de alta precisão com trilhos de energia ciano. 6 disparos por tambor, hitscan instantâneo com multiplicador de Headshot (2x). RMB carrega e dispara um feixe perfurante que atravessa múltiplos inimigos em linha reta.

---

## 5. Inimigos do MVP

* **Stalker Husk:** Humanoide ágil biomecânico que corre direto na direção do jogador para golpear corpo a corpo. Perfeito para alimentar o jogador com sangue.
* **Sentinel Orb:** Drone esférico flutuante com anéis giroscópicos. Mira com um feixe laser e dispara uma esfera de plasma vermelho visível que exige esquiva no Dash.

---

## 6. Roster de Fases & Campanhas

| Código | Fase | Cenário / Arquitetura | Mecânicas de Destaque |
| :--- | :--- | :--- | :--- |
| **`00`** | **Proving Grounds (Test Arena)** | Sandbox aberto de treino | Hordas infinitas, treino de mira e mobilidade livre. |
| **`01`** | **The Incinerator (Level 01)** | Usina siderúrgica de 4 setores | Rios de escória, caldeirão central, jump pads e rampa de descida. |
| **`02`** | **Blood Cathedral (Level 02)** | Basílica gótico-industrial | Vitrais rubi, abismo com plataformas flutuantes e o Grande Altar Sacrificial. |

---

## 7. Estrutura do Projeto

```text
C:\Users\du-xb\Documents\games\BLOODSURGE
├── assets/
│   ├── audio/        # FX de tiros, passos, estilhaços e guitarras procedurais
│   ├── models/       # Malhas .glb otimizadas (husk.glb, sentinel.glb)
│   ├── materials/    # Materiais PBR/Triplanar com texture filter Nearest
│   └── textures/     # Texturas retro 256x256 pixel art tileáveis
├── scenes/
│   ├── player/       # Player.tscn (CharacterBody3D, Câmera, Armas)
│   ├── weapons/      # Shotgun.tscn, ShotgunShellCasing.tscn
│   ├── enemies/      # Husk.tscn, Sentinel.tscn, BloodGib.tscn, PlasmaBall.tscn
│   ├── arena/        # TestArena.tscn, Level01_Incinerator.tscn, Level02_Cathedral.tscn
│   └── ui/           # MainMenu.tscn, HUD.tscn (Painel de Vitória com Próxima Fase)
├── scripts/
│   ├── player/
│   ├── weapons/
│   ├── enemies/
│   ├── arena/
│   ├── ui/
│   └── core/
├── GDD.md
├── jogar.bat
└── project.godot
```
