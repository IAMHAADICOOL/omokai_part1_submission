# Omokai — Core Task: Prompt → LLM → Validated JSON → Deterministic Executor → Sim

A natural-language command drives a TurtleBot3 around a predetermined loop in
Gazebo. An LLM only *proposes* a plan; a schema validator gates it; a
deterministic, auditable executor carries it out. **The LLM is never in the
control loop.**

```
prompt (NL) → LLM planner → candidate JSON → validator → validated JSON → executor → Nav2/Gazebo
              (proposes)                     (guardrail)                 (deterministic, sha256-audited)
```

---

## 0. One-time prerequisite: add your saved map

The default demo localizes in a pre-built map of `turtlebot3_world`. Copy your
two saved map files into the repo before building:

```
src/omokai_bringup/maps/turtlebot3_world.yaml
src/omokai_bringup/maps/turtlebot3_world.pgm
```

(If you don't have them yet, build one first with `slam:=True` — see §4.)

---

## 1. Run with Docker (recommended)

You do **not** need to know Docker. Two containers start together: one runs the
LLM (Ollama), one runs ROS 2 + Gazebo + the pipeline. Rendering is done on the
CPU, so it works on any machine regardless of GPU.

### 1a. Install Docker (once)
```bash
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER    # then log out and back in
```
If apt reports a `containerd.io` / `containerd` conflict, you already have a
different Docker stack installed. Remove the old Docker CE packages first, or
keep using that stack instead of mixing them:
```bash
sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt install -y docker.io docker-compose-v2
```

### 1b. Allow GUI windows from the container (once per login)
```bash
xhost +local:docker
```

### 1c. Build and run (one command)
```bash
docker compose up --build
```
First run takes a while: it builds the image and downloads the ~2 GB model.
Gazebo, RViz, and four small terminal windows (the pipeline) will appear.

### 1d. Issue a command
In the **"1 INTERFACE"** window, type a prompt and press Enter:
```
Patrol the perimeter loop twice
```
Watch the robot drive the loop in Gazebo.

### 1e. Stop
`Ctrl-C` in the terminal, then:
```bash
docker compose down
```

### The only Docker commands you need
| Command | What it does |
|---|---|
| `docker compose up --build` | build (if needed) and start everything |
| `docker compose up` | start (already built) |
| `docker compose down` | stop and remove the containers |
| `docker compose exec ros bash` | open a shell *inside* the running ROS container |
| `docker compose logs -f ros` | watch the ROS container's output |

---

## 2. Run natively (no Docker)

For Ubuntu 24.04 + ROS 2 Jazzy. From the repo root:
```bash
bash install_native.sh          # installs ROS 2, Gazebo, TB3, Nav2, Ollama, deps
# open a NEW terminal, then:
ros2 launch omokai_bringup core_pipeline.launch.py
```
Then type a prompt in the "1 INTERFACE" window (same as §1d).

Exact versions are in `DEPENDENCIES.md`.

---

## 3. What each prompt does & what to expect

| Prompt | Expected behaviour |
|---|---|
| `Patrol the perimeter loop twice` | robot drives the perimeter route, 2 loops |
| `Drive the perimeter once and return` | one loop |
| `Speed 5 m/s around the loop` | **rejected** by the validator (over safe speed) — shown in the VALIDATOR window |

The four windows show the pipeline live: **INTERFACE** (you type) → **LLM
PLANNER** (candidate JSON) → **VALIDATOR** (accept/reject + reason) → **EXECUTOR**
(the `AUDIT` line with the mission's sha256, then waypoint progress).

---

## 4. Build a map (optional, `slam:=True`)
```bash
ros2 launch omokai_bringup core_pipeline.launch.py slam:=True
ros2 run turtlebot3_teleop teleop_keyboard          # drive to build the map
ros2 run nav2_map_server map_saver_cli -f src/omokai_bringup/maps/turtlebot3_world
```
Note the **capital** `True`/`False`: Nav2 evaluates that argument in Python.

---

## 5. Architecture (why it's built this way)

- **mission_schemas** — the single source of truth: a Pydantic `Mission` model
  (command type, route, waypoints, loops, speed constraints). Everything speaks
  this contract.
- **mission_interface** — publishes your typed prompt to `/mission/prompt`.
- **mission_llm_planner** — sends the prompt to Ollama with the schema as a
  structured-output constraint (temperature 0). It only *proposes* candidate JSON.
- **mission_validator** — re-validates against the schema **and** safety rules
  (speed ≤ 0.22 m/s, known routes, loop bounds). Passes → `/mission/validated`,
  fails → `/mission/rejected`. This is the guardrail.
- **mission_executor** — reads validated JSON only, drives Nav2's
  `FollowWaypoints`, and logs an `AUDIT` line with `sha256(json)`. Deterministic
  and auditable: same JSON → same behaviour, every time.

This satisfies the evaluation principles directly: LLM kept out of the control
loop, JSON schema-validated, executor deterministic and auditable.

See `docs/SOURCES.md` for cited sources and licenses.
