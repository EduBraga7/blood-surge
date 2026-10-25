# BLOODSURGE 🩸⚡

<div align="center">

![Godot Engine](https://img.shields.io/badge/Godot-4.7-blue?logo=godotengine&logoColor=white)
![Genre](https://img.shields.io/badge/Genre-Boomer%20Shooter%20%2F%20Movement%20FPS-crimson)
![Status](https://img.shields.io/badge/Status-Playable%20Alpha-darkgreen)
![Platform](https://img.shields.io/badge/Platform-Windows%20%2F%20PC-lightgrey)

**"O movimento é sua única armadura. O sangue inimigo é seu combustível."**

*A fast-paced, high-octane retro movement FPS inspired by Ultrakill, Doom (1993/2016), Dusk, and Quake.*

[Visão Geral](#-visão-geral) • [Mecânicas](#-mecânicas-centrais) • [Arsenal](#-arsenal) • [Bestiário](#-bestiário) • [Fases](#-campanha--fases) • [Controles](#-controles) • [Como Jogar](#-como-jogar)

</div>

---

## ⚡ Visão Geral

**BLOODSURGE** é um jogo de tiro em primeira pessoa focado em reflexos imediatos, mobilidade acrobática, mira precisa e agressividade ininterrupta. 

Você não recua e não busca cobertura: toda mecânica de sobrevivência depende de avançar em direção aos inimigos, despedaçá-los à queima-roupa e absorver o sangue vital que jorra dos seus corpos para restaurar seu HP.

---

## 🩸 Mecânicas Centrais

* **Blood Siphon (Cura por Sangue):** Eliminações e danos pesados em curto alcance (< 4.5m) liberam jorros de sangue e gibs que curam o jogador instantaneamente.
* **Sistema de Estilo (Style Ranks):** Encadeie dano variado, velocidade e parries para subir de rank:
  $$\text{FRESH} \rightarrow \text{CARNAGE} \rightarrow \text{BRUTAL} \rightarrow \text{ANARCHIC} \rightarrow \text{SUPREME} \rightarrow \text{SSADISTIC} \rightarrow \text{ULTRAKILL}$$
* **Mobilidade Extrema:**
  * **Omnidirectional Dash:** Esquiva rápida com 3 cargas recarregáveis e onda de choque visual.
  * **Ground Slide:** Deslize rente ao solo soltando faíscas, preservando momento até 28 m/s.
  * **Dynamic Speed FOV Kick:** Abertura visual da câmera (95° a 108°) ao quebrar a barreira de velocidade.
* **Punch & Parry:** Golpe corpo a corpo devastador que reflete projéteis inimigos e causa cura de emergência.
* **Impacto Visceral (Game Feel):**
  * Hitstop (micro-congelamento de 50ms) em abates críticos.
  * Screen shake baseado em trauma não-linear.
  * Hitmarkers auditivos com som mecânico (*CRUNCH*).
  * Decalques persistentes de sangue espirrados nas paredes e pisos.

---

## 🔫 Arsenal

### 1. Super Shotgun (Cano Duplo)
* **Primário (LMB):** Disparo massivo de 10 balins de chumbo com ampla dispersão e alto recuo.
* **Secundário (RMB):** Disparo duplo sincronizado, destruição catastrófica em alvos próximos.

### 2. Piercer Revolver (Canhão de Precisão)
* **Primário (LMB):** Hitscan instantâneo de precisão cirúrgica com multiplicador de Headshot (2x).
* **Secundário (RMB):** Carrega e projeta um **Feixe Perfurante** ciano que transpassa múltiplos inimigos em linha reta.

---

## 👾 Bestiário

| Inimigo | Comportamento | Estratégia Recomendada |
| :--- | :--- | :--- |
| **Stalker Husk** | Humanoide biomecânico veloz que persegue em linha reta para golpes violentos. | Mire na cabeça com o Revolver ou use o Shotgun à queima-roupa para colher sangue. |
| **Sentinel Drone** | Esfera flutuante com giroscópios que telegrafa com laser e dispara orbes de plasma. | Esquive do plasma no Dash, reflita com o soco (`F`) ou destrua à distância com o Piercer. |

---

## 🏛️ Campanha & Fases

O jogo inclui um seletor completo de fases no menu principal e progressão contínua:

1. **`[00]` Proving Grounds (Test Arena):** Sandbox de combate para aquecimento e treino livre de acrobacias.
2. **`[01]` The Incinerator (Level 01):** Usina industrial com 4 setores, rios de escória fervente, caldeirão central e saltos em jump-pads.
3. **`[02]` Blood Cathedral (Level 02):** Basílica gótico-industrial com naves colossais, vitrais de rubi, abismos com plataformas suspensas e o Grande Altar Sacrificial.

---

## 🎮 Controles

| Tecla / Entrada | Ação |
| :--- | :--- |
| `W, A, S, D` | Movimentação em 8 direções (13.5 m/s base) |
| `Mouse` | Mirar / Rotação livre de câmera |
| `Espaço` | Pulo com controle aéreo ágil |
| `Shift` | Dash direcional (3 cargas) |
| `Ctrl` | Slide veloz no solo com faíscas |
| `1, 2` ou `Q` / `Roda do Mouse` | Alternar Armas (Shotgun / Revolver) |
| `Botão Esquerdo (LMB)` | Disparo Primário |
| `Botão Direito (RMB)` | Disparo Alternativo / Carregar Feixe Perfurante |
| `F` | Soco Melee / Parry de Projéteis |
| `R` | Reiniciar fase instantaneamente |
| `ESC` | Pausar jogo / Menu de Opções |

---

## 🚀 Como Jogar

### Pré-requisitos
* [Godot Engine 4.7](https://godotengine.org/) (compatível com Godot 4.3+ Standard ou .NET)
* Windows 10/11 (ou Linux via Godot)

### Execução Imediata
Basta clonar o repositório e executar o script de inicialização rápida:

```cmd
git clone https://github.com/EduBraga7/blood-surge.git
cd blood-surge
jogar.bat
```

Ou abra o projeto diretamente no editor do Godot importando o arquivo `project.godot`.

---

## 🛠️ Arquitetura Técnica

* **Linguagem:** GDScript 2.0 estaticamente tipado (`@export`, tipos explícitos para alta performance e zero alocação desnecessária).
* **Física:** `CharacterBody3D` em `_physics_process` com interpolação de câmera em `_process`.
* **Áudio Procedural:** Sintetizadores embutidos em tempo de execução para sub-bass kicks e percussões dinâmicas sem arquivos externos pesados.
* **Pipelines 3D:** Modelos `.glb` low-poly otimizados, materiais PBR triplanares e shaders customizados retro-crunch.

---

## 📄 Licença

Distribuído sob a licença MIT. Consulte `LICENSE` para mais detalhes.
