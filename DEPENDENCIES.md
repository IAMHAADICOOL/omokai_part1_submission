# Exact dependency / version list

Target OS: **Ubuntu 24.04 LTS (Noble)**  ·  ROS 2: **Jazzy Jalisco**  ·  Gazebo: **Harmonic (gz-sim 8)**

## System / ROS packages (apt)
| Package | Purpose |
|---|---|
| ros-jazzy-desktop | ROS 2 Jazzy + RViz2 (native install) |
| ros-jazzy-ros-gz | Gazebo Harmonic + ROS↔Gazebo bridge |
| ros-jazzy-turtlebot3, -msgs, -simulations | robot model, world, sim launch |
| ros-jazzy-navigation2, ros-jazzy-nav2-bringup | Nav2 stack (AMCL, costmaps, controllers) |
| ros-jazzy-slam-toolbox | 2D SLAM (used only in `slam:=True` mapping mode) |
| xterm | each pipeline node runs in its own terminal |
| python3-pip, python3-colcon-common-extensions | build tooling |

## Python packages (pip)
| Package | Version | Purpose |
|---|---|---|
| pydantic | >= 2.0 | mission JSON schema + validation |
| ollama | >= 0.3.0 | client for the local LLM |

## LLM
| Tool | Version | Notes |
|---|---|---|
| Ollama | latest | local inference server (`ollama serve`) |
| Model | qwen2.5:3b | ~2 GB; runs CPU-only if no GPU |

## Environment variables
| Var | Value | Why |
|---|---|---|
| TURTLEBOT3_MODEL | burger | selects the robot model |
| LLM_MODEL | qwen2.5:3b | model the planner requests |
| OLLAMA_HOST | http://localhost:11434 (native) / http://ollama:11434 (Docker) | where the planner reaches Ollama |
