#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Native (no-Docker) setup for Ubuntu 24.04 (Noble) + ROS 2 Jazzy.
# Installs ROS 2, Gazebo Harmonic, TurtleBot3, Nav2, Ollama, and the Python deps,
# then builds this workspace. Run from the repo root:  bash install_native.sh
# ─────────────────────────────────────────────────────────────────────────────
set -e

echo "==> [1/6] ROS 2 Jazzy apt repository"
sudo apt update && sudo apt install -y software-properties-common curl gnupg lsb-release
sudo add-apt-repository -y universe
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update

echo "==> [2/6] ROS 2 Jazzy + Gazebo Harmonic + TurtleBot3 + Nav2"
sudo apt install -y \
  ros-jazzy-desktop \
  ros-jazzy-ros-gz \
  ros-jazzy-turtlebot3 \
  ros-jazzy-turtlebot3-msgs \
  ros-jazzy-turtlebot3-simulations \
  ros-jazzy-navigation2 \
  ros-jazzy-nav2-bringup \
  ros-jazzy-slam-toolbox \
  xterm python3-pip python3-colcon-common-extensions

echo "==> [3/6] Python deps (pydantic + ollama client)"
pip3 install --break-system-packages "pydantic>=2.0" "ollama>=0.3.0"

echo "==> [4/6] Ollama (local LLM runtime) + model"
if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
fi
# start the server in the background if it isn't already running, then pull model
(ollama serve >/dev/null 2>&1 &) || true
sleep 3
ollama pull qwen2.5:3b

echo "==> [5/6] Build the workspace"
source /opt/ros/jazzy/setup.bash
colcon build --symlink-install

echo "==> [6/6] Environment variables (added to ~/.bashrc if missing)"
add_line() { grep -qxF "$1" ~/.bashrc || echo "$1" >> ~/.bashrc; }
add_line "source /opt/ros/jazzy/setup.bash"
add_line "source $(pwd)/install/setup.bash"
add_line "export TURTLEBOT3_MODEL=burger"
add_line "export LLM_MODEL=qwen2.5:3b"
# OLLAMA_HOST defaults to http://localhost:11434 natively -- no need to set it.

echo
echo "Done. Open a NEW terminal (so ~/.bashrc is re-sourced), then:"
echo "    ros2 launch omokai_bringup core_pipeline.launch.py"
