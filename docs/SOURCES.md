# Cited Sources

Every external repo/tool we build on, with license and exactly what we take.
Filled in as each phase lands (Condition 4.2: cite every source).

| Component | Repo / URL | License | What we use | Phase |
|---|---|---|---|---|
| Sim base + robot | ROBOTIS-GIT/turtlebot3_simulations (jazzy) | Apache-2.0 | robot model, worlds, ros_gz launch | 0 |
| TB3 core pkgs | ROBOTIS-GIT/turtlebot3 | Apache-2.0 | description, bringup | 0 |
| Navigation | ros-navigation/navigation2 (Nav2) | Apache-2.0 | NavigateThroughPoses, costmaps, AMCL | 1 |
| LLM runtime | ollama/ollama | MIT | local inference + structured outputs | 1 |
| Architecture ref | Auromix/ROS-LLM | Apache-2.0 | NL->ROS node pattern (reference only) | 1 |
| Architecture ref | Gaurang-1402/ChatDrones | MIT | ROSGPT-style JSON-emit pattern (reference only) | 1 |
| Multi-robot | arshadlab/tb3_multi_robot (master = Jazzy/Harmonic) | Apache-2.0 | namespaced multi-TB3 + per-robot Nav2 (found independently -- not in task's compiled list, which has no ground-robot swarm repo) | 2 |
| Formation geometry | Original (this repo) | n/a | line/column/wedge offset math in geometry.py, written from scratch, unit-tested | 2 |
| SLAM | SteveMacenski/slam_toolbox | LGPL-2.1 | online 2D async SLAM | 3 |
| SLAM (3D alt) | introlab/rtabmap_ros | BSD | optional visual/3D SLAM | 3 |
| Vision | ultralytics/ultralytics | AGPL-3.0 | detection/tracking (mind AGPL for distribution) | 4 |
| Vision ref | monemati/PX4-ROS2-Gazebo-YOLOv8 | check repo | cam->YOLO->follow pattern (ported) | 4 |

> **Why no repo from the task's "Multi-agent / swarm (Challenge 1)" table** (PX4_Swarm_Controller,
> px4_multi_drone_sim, gym-pybullet-drones, Crazyswarm2, mavsdk_drone_show) is used: every one
> is PX4/MAVLink/Crazyflie-specific. The core task here is a ground robot (TurtleBot3 + Nav2), and
> the task doc requires each challenge to "work along with the core task ... as an extension of the
> core task" -- adopting a drone flight-stack repo would mean running a second, disconnected robot
> stack instead of extending Phase 1's ROS2/Nav2 pipeline. The formation_coordinator's offset
> geometry (line/column/wedge) is conceptually the same idea PX4_Swarm_Controller describes
> ("configurable formation geometry") but is independently written for Nav2's FollowWaypoints
> action, not ported from it -- no line of that repo's code was read or reused.

> TODO: pin exact commit SHAs + confirm each LICENSE file at integration time.
> Note: ultralytics is AGPL-3.0 — flag licensing implications in the write-up.
