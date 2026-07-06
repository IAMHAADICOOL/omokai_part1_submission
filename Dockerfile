# ─────────────────────────────────────────────────────────────────────────────
# Omokai core-task image: ROS 2 Jazzy + Gazebo Harmonic + TurtleBot3 + Nav2,
# plus the mission pipeline packages. Built once; runs the same everywhere.
# ─────────────────────────────────────────────────────────────────────────────

# Official ROS 2 Jazzy base (Ubuntu 24.04 under the hood). Pins the ROS distro
# so the examiner's host distro is irrelevant.
FROM ros:jazzy-ros-base

# Non-interactive apt (no prompts during build).
ENV DEBIAN_FRONTEND=noninteractive

# ── System + ROS dependencies ────────────────────────────────────────────────
# Each line is a deliberate dependency of the core task:
#   ros-gz*              : Gazebo Harmonic + the ROS<->Gazebo bridge
#   turtlebot3*          : robot model, world, and sim launch files
#   navigation2/nav2     : Nav2 stack (AMCL localization, costmaps, controllers)
#   slam-toolbox         : only used by `slam:=True` (mapping mode); harmless otherwise
#   rviz2                : visualization
#   xterm                : the pipeline nodes each run in their own xterm
#   curl                 : entrypoint uses it to pull the LLM model from Ollama
#   python3-pip          : for the two pip-only Python deps below
RUN apt-get update && apt-get install -y --no-install-recommends \
      ros-jazzy-ros-gz \
      ros-jazzy-turtlebot3 \
      ros-jazzy-turtlebot3-msgs \
      ros-jazzy-turtlebot3-simulations \
      ros-jazzy-navigation2 \
      ros-jazzy-nav2-bringup \
      ros-jazzy-slam-toolbox \
      ros-jazzy-rviz2 \
      xterm curl python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ── Python deps not packaged as ROS debs ─────────────────────────────────────
#   pydantic : the mission JSON schema / validator
#   ollama   : Python client that talks to the Ollama service
# (--break-system-packages is required on Ubuntu 24.04's externally-managed pip)
RUN pip3 install --no-cache-dir --break-system-packages \
      "pydantic>=2.0" "ollama>=0.3.0"

# ── Build the workspace ──────────────────────────────────────────────────────
WORKDIR /ws
COPY src/ /ws/src/
# Build against the sourced ROS environment, then the image already contains a
# compiled workspace (fast, reproducible startup).
RUN . /opt/ros/jazzy/setup.sh && \
    colcon build --symlink-install

# ── Runtime environment ──────────────────────────────────────────────────────
ENV TURTLEBOT3_MODEL=burger \
    LLM_MODEL=qwen2.5:3b \
    OLLAMA_HOST=http://ollama:11434 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    QT_X11_NO_MITSHM=1

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
# Default: launch the core pipeline (localization + prompt->LLM->JSON->executor).
CMD ["ros2", "launch", "omokai_bringup", "core_pipeline.launch.py"]
