# Omokai — Core Task
### Type an instruction in plain English → a robot drives itself in a simulator

You type something like *"patrol the perimeter twice."* A local AI turns that
sentence into a small plan. A safety checker makes sure the plan is allowed.
Then a simple, predictable program drives the robot around the map in Gazebo
(the simulator). **The AI only suggests the plan — it never drives the robot.**

```
your words → AI planner → draft plan → safety checker → approved plan → driver → robot in simulator
             (suggests)   (JSON)      (guardrail)                      (predictable, logged)
```

Each stage is a separate ROS 2 package. **Every package has its own README.md**
inside its folder (open the folder on GitHub to read it) that explains that
package in detail — what it does, what it reads, and what it produces. Start
here for setup; go into a package's README to understand that piece.

---

---

## Getting the code (do this first)

Clone the repository and move into its folder. **Every command in this guide is
run from the repository's root folder** (the one containing `docker-compose.yml`,
`Dockerfile`, and the `src/` folder) unless it says otherwise.

```bash
git clone <YOUR-REPO-URL> omokai_core
cd omokai_core
```

You should now be inside `omokai_core/`. Check you're in the right place:
```bash
ls
# you should see: Dockerfile  docker-compose.yml  install_native.sh  src  docs  README.md ...
```
Stay in this folder for everything below (Docker build, native install, the map
step, etc.). The only time you go elsewhere is *inside* the Docker box, which is
covered in Section 5.

## 0. One-time: add your saved map

The normal demo drives around a **saved map** of the world. From the repo root,
put your two map files at these paths (relative to the repo root) before you
build:

```
src/omokai_bringup/maps/turtlebot3_world.yaml
src/omokai_bringup/maps/turtlebot3_world.pgm
```

Don't have a map yet? Make one — see **Section 4**.

---

## 1. Run it with Docker (easiest — recommended)

You don't need to know Docker. Think of Docker as a **pre-built, sealed
computer-in-a-box**: everything (ROS 2, the simulator, all the software) is
already installed inside, so it runs the same on any machine. We start **two
boxes**: one runs the AI, the other runs the robot software. (Why two? See
Section 6.)

### 1a. Install Docker (only once, ever)
```bash
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER    # lets you run docker without sudo
# now LOG OUT and back in (so the group change takes effect)
```
If apt complains about a `containerd.io` / `containerd` conflict, you already
have a different Docker installed — either use that, or remove the old one:
```bash
sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt install -y docker.io docker-compose-v2
```

### 1b. Let the boxes open windows on your screen (once each time you log in)
```bash
xhost +local:docker
```
This gives the container permission to show the Gazebo / RViz / terminal
windows on your desktop. Without it, the program runs but no windows appear.

### 1c. Build and start everything (one command)
```bash
docker compose up --build
```
What this does, in order:
- **builds** the box from the recipe (`Dockerfile`) — installs ROS 2, Gazebo, etc.
- **starts** the AI box and downloads the ~2 GB AI model (first time only)
- **starts** the robot box, which opens Gazebo, RViz, and four small terminals

The first run is slow (building + downloading). Later runs are fast.

### 1d. Give the robot a command
Click the window titled **"1 INTERFACE"**, type this, and press Enter:
```
Patrol the perimeter loop twice
```
Watch the robot drive the loop in the Gazebo window.

### 1e. Stop everything
Press `Ctrl-C` in the terminal where you ran the command, then:
```bash
docker compose down
```
This shuts down and removes both boxes cleanly.

### The handful of Docker commands you'll actually use
| Command | Plain-English meaning |
|---|---|
| `docker compose up --build` | build the box (if needed) and start everything |
| `docker compose up` | start everything (already built — faster) |
| `docker compose down` | stop and remove the boxes |
| `docker compose exec ros bash` | **open a terminal inside** the running robot box (see §5) |
| `docker compose logs -f ros` | watch the robot box's messages scroll by |

---

## 2. Run it without Docker (native install)

For a clean **Ubuntu 24.04** machine with nothing conflicting. Run from the repo
root (the `omokai_core/` folder you cloned into):
```bash
bash install_native.sh    # installs ROS 2, Gazebo, TurtleBot3, Nav2, Ollama, + Python bits
# open a NEW terminal (so the settings load), then:
ros2 launch omokai_bringup core_pipeline.launch.py
```
Then type a prompt in the "1 INTERFACE" window, exactly like §1d.
Exact package versions are listed in `DEPENDENCIES.md`.

---

## 3. What to type, and what should happen

| You type | What happens |
|---|---|
| `Patrol the perimeter loop twice` | robot drives the perimeter route, 2 times |
| `Drive the perimeter once and return` | one loop |
| `Speed 5 m/s around the loop` | **rejected** — too fast; the VALIDATOR window says why |

The four terminal windows are the pipeline, left to right:
**INTERFACE** (you type) → **LLM PLANNER** (shows the draft plan as JSON) →
**VALIDATOR** (shows accepted or rejected + the reason) → **EXECUTOR** (prints
an `AUDIT` line with a fingerprint of the plan, then the robot's progress).

---

## 4. Make your own map (mapping mode)
```bash
ros2 launch omokai_bringup core_pipeline.launch.py slam:=True
ros2 run turtlebot3_teleop teleop_keyboard    # drive the robot around to build the map
ros2 run nav2_map_server map_saver_cli -f src/omokai_bringup/maps/turtlebot3_world
```
Then rebuild so the map gets picked up: `colcon build --symlink-install`.

**Important:** write `slam:=True` / `slam:=False` with a **capital** letter —
Nav2 reads this value as Python code, and only `True`/`False` work.

Where the robot starts is set in one place: `src/omokai_bringup/config/spawn_pose.yaml`.
That file feeds both the simulator (where the robot appears) and the localizer
(where it thinks it is), so they always agree and you never have to click a
"2D Pose Estimate" in RViz. See the comments in that file.

---

## 5. Working inside the Docker box

### Open another terminal inside the running robot box
While `docker compose up` is running, open a **new** terminal on your computer and:
```bash
docker compose exec ros bash
```
You are now *inside* the robot box. ROS 2 and the project are already loaded, so
you can run ROS commands directly, e.g.:
```bash
ros2 topic list
ros2 run turtlebot3_teleop teleop_keyboard --ros-args -r /cmd_vel:=/cmd_vel
```
Type `exit` to leave the inner terminal (the robot box keeps running).

### Add a new ROS package to the box
1. Put your new package folder under `src/` on your computer:
   ```
   src/my_new_package/
   ```
2. Rebuild the box so it copies the new code in and compiles it:
   ```bash
   docker compose up --build
   ```
   (The recipe copies everything in `src/` and runs the build automatically.)

   **Faster, while developing:** instead of rebuilding the whole box each time,
   open a terminal inside the box (above) and rebuild just the workspace:
   ```bash
   docker compose exec ros bash
   cd /ws && colcon build --symlink-install && source install/setup.bash
   ```
   For this to see your latest code without a full rebuild, mount your `src/`
   into the box by adding this under the `ros` service in `docker-compose.yml`:
   ```yaml
       volumes:
         - ./src:/ws/src
   ```
   Then edits on your computer show up inside the box instantly; you just
   re-run `colcon build` in the box.

---

## 6. Why two separate boxes (ROS box + Ollama box)?

We run ROS/Gazebo in one container and the AI (Ollama) in another, on purpose:

- **Each box does one job.** The AI box is a standard, ready-made Ollama image
  we didn't have to build. The robot box only needs ROS/Gazebo. Mixing them
  would mean a bigger, more fragile custom image.
- **The AI model is downloaded once and kept.** The ~2 GB model lives in the AI
  box's own storage (a Docker "volume"), so rebuilding the robot box doesn't
  wipe or re-download it.
- **They restart independently.** You can rebuild/restart the robot software
  without touching the AI, and vice-versa.
- **It mirrors reality.** On a real robot the LLM often runs as its own service
  (its own process/machine); keeping them separate here matches that and makes
  the boundary between "AI that suggests" and "software that acts" explicit.

The two boxes talk over a private network Docker sets up automatically: the
robot box reaches the AI at the address `http://ollama:11434` (set by the
`OLLAMA_HOST` environment variable in `docker-compose.yml`).

---

## 7. How the pieces fit together (architecture)

Each item is a ROS 2 package with its **own detailed README.md** inside its folder:

- **mission_schemas** — the shared "contract": the exact shape a valid plan must
  have (command type, route, loops, speed limits). Every other package uses it.
- **mission_interface** — takes the sentence you type and puts it on the
  `/mission/prompt` channel.
- **mission_llm_planner** — asks the local AI (Ollama) to turn the sentence into
  a draft plan that fits the contract. It only *suggests*.
- **mission_validator** — the guardrail. Re-checks the draft against the contract
  **and** safety rules (speed ≤ 0.22 m/s, known routes). Good → `/mission/validated`;
  bad → `/mission/rejected` with a reason.
- **mission_executor** — reads only approved plans, drives the robot through Nav2,
  and logs a fingerprint (`sha256`) of each plan. Same plan → same behavior, always.
- **omokai_bringup** — the "start everything" package: launch files, the map,
  routes, robot settings, and the spawn-pose config.

This is why the design is safe and gradeable: the AI is kept **out of the control
loop**, every plan is **schema-checked**, and the driver is **predictable and
logged**.

Sources and licenses: `docs/SOURCES.md`.
