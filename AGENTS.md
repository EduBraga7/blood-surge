# AGENTS.md — AI Developer Directives & Operational Rules

> **Project:** BLOODSURGE  
> **Engine:** Godot Engine 4.7  
> **Genre:** Fast-Paced Movement FPS / Boomer Shooter  
> **Audience:** Any AI agent, LLM, or automated tool operating on this codebase.  
> **Status:** Mandatory. All modifications must comply with the rules below.

---

## 1. Strict Anti-Overengineering & Concrete Implementations (YAGNI)

* **Rule 1.1 — Ban on Speculative Abstractions:**
  * Do NOT create abstract base classes, generic factories, dependency injection containers, service locators, or multi-tier event buses when a direct, concrete solution works.
  * Never write code to support hypothetical future features. Build solely what the immediate task requires.
* **Rule 1.2 — Flat & Idiomatic Godot Composition:**
  * Use Godot's native scene tree hierarchy directly.
  * Direct method calls downward (parent calls child); native Godot signals upward (child notifies parent).
  * Keep scripts short, single-responsibility, and co-located with their `.tscn` scenes.
* **Rule 1.3 — Concrete First, Refactor Later:**
  * If a feature only exists once (e.g., a single weapon or single enemy type), code it directly. Do not invent an extensible framework until multiple concrete implementations actually demand it.

---

## 2. Phase-Gated Complexity Rule

* **Rule 2.1 — Complexity Must Be Pre-Mapped:**
  * Implementing a more abstracted, generalized, or multi-layered architecture is **STRICTLY PROHIBITED** unless that specific requirement is explicitly mapped to a designated future development milestone in `GDD.md` or `ROADMAP.md`.
* **Rule 2.2 — Default to the Simplest Functional Solution:**
  * When executing any milestone, always choose the path with the fewest files, least indirection, and lowest conceptual overhead.
  * If future requirements demand polymorphism or data-driven decoupling, refactoring must happen in that designated future phase, never prematurely.

---

## 3. Experience-First Request Interpretation

* **Rule 3.1 — Target the Player Sensation (Not Just the Literal Syntax):**
  * When the user requests a feature, inspect the **tactile gameplay sensation, pacing, urgency, and kinetic feedback** they are trying to produce, rather than mindlessly implementing the literal words.
  * Example: If the user says "add a heavy melee attack", do not just write an invisible raycast that subtracts HP. Deliver the sensation: screen trauma, audible crunch, enemy stagger, impact freeze-frame, and forward lunge momentum.
* **Rule 3.2 — The Feel Test:**
  * If an implementation is technically bug-free according to code standards but feels sluggish, disconnected, floaty, or boring to play, **the task is considered incomplete and failed**.

---

## 4. No Subjective Bias on Mechanics (Precedents Over Opinions)

* **Rule 4.1 — Eliminate Personal Value Judgments:**
  * Never label a mechanic "good", "bad", "annoying", or "unbalanced" based on subjective opinions, personal taste, or theoretical game design tropes.
* **Rule 4.2 — Ground Decisions in Proven Commercial Precedents:**
  * Whenever there is uncertainty or ambiguity regarding a mechanical choice (e.g., hitstop duration, shotgun spread angle, dash cooldowns, time-to-kill, blood siphon recovery radius, enemy telegraph chimes), **always search for, cite, and emulate proven commercial precedents** that have successfully shipped and succeeded.

---

## 5. Prioritize Mechanical Precedents (Ignore Visual/Narrative Themes)

* **Rule 5.1 — Benchmark Strictly by Mechanical DNA:**
  * When researching references, balance figures, and gameplay solutions, **ALWAYS prioritize games sharing the exact mechanical genre of this project**, regardless of their visual setting, story, or lore.
  * **Primary Mechanical Benchmarks:**
    * *Ultrakill* (Movement tech, slide-hopping, dash i-frames, point-blank blood healing, hitstop, weapon swap rhythm)
    * *Doom (1993 / 2016 / Eternal)* (Arena flow, projectile dodge dancing, aggressive push-forward combat, visceral feedback)
    * *Dusk* / *Quake* (Raw air control, speed preservation, snappy hitscan feel, high FOV readability)
    * *Turbo Overkill* / *Devil Daggers* (High-speed projectile density, immediate audio cues, high-tempo combat loops)
* **Rule 5.2 — Disregard Thematic Distractions:**
  * Do NOT borrow systems, pacing, or mechanics from games that share dark fantasy, demonic, or blood themes (e.g., *Dark Souls*, *Diablo*, *Vampire Survivors*, *Castlevania*) unless they are first-person movement shooters.
  * Narrative and art are visual wrappers; mechanics dictate the code.

---

## 6. Godot 4.7 Technical Standards

1. **Static Typing:** Always use explicit GDScript type hints (`var speed: float = 12.0`, `func take_damage(dmg: float) -> bool:`).
2. **Expose Game-Feel Knobs:** Use `@export` for balancing parameters (speeds, durations, damages, spreads) so they can be tuned instantly in the Inspector.
3. **Physics vs. Render Separation:**
   * Movement, gravity, collisions, and raycasts belong strictly in `_physics_process(delta)`.
   * Camera look, visual weapon sway, and UI interpolations belong in `_process(delta)`.
4. **Collision Matrix Discipline:**
   * Layer 1: `World`
   * Layer 2: `Player`
   * Layer 3: `Enemies`
   * Layer 4: `Projectiles`
   * Layer 5: `BloodGibs`
   * Keep collision masks strictly filtered to prevent wasted physics checks.
5. **Zero Compile Delay:** Test modifications using the headless runner or direct launcher:
   ```cmd
   jogar.bat
   ```
