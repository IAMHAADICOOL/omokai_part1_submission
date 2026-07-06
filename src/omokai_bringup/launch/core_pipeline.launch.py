"""Phase 1 pipeline with two modes, selected by `slam:=`.

MAPPING (build a map to save):
    ros2 launch omokai_bringup core_pipeline.launch.py slam:=True
    # in another terminal, drive:
    ros2 run turtlebot3_teleop teleop_keyboard
    # when the map looks complete, save it INTO the package:
    ros2 run nav2_map_server map_saver_cli -f \
        src/omokai_bringup/maps/turtlebot3_world
    # then rebuild so the map installs:
    colcon build --symlink-install

RUN (localize in the saved map + full prompt->LLM->JSON->executor pipeline):
    ros2 launch omokai_bringup core_pipeline.launch.py            # slam:=False (default)
    ros2 launch omokai_bringup core_pipeline.launch.py map:=/abs/path/map.yaml

NOTE: pass slam:=True / slam:=False with a capital letter -- nav2's own
bringup_launch.py evaluates this argument with a Python-style eval() internally,
and only True/False (not true/false) are valid Python literals.

Requires: sudo apt install xterm
"""
import os
import math

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument,
    ExecuteProcess,
    IncludeLaunchDescription,
    TimerAction,
)
from launch.conditions import UnlessCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    bringup = get_package_share_directory("omokai_bringup")
    nav2 = get_package_share_directory("nav2_bringup")

    slam = LaunchConfiguration("slam")
    map_yaml = LaunchConfiguration("map")

    routes_file = os.path.join(bringup, "config", "routes.yaml")
    nav2_params = os.path.join(bringup, "config", "nav2_params.yaml")
    default_map = os.path.join(bringup, "maps", "turtlebot3_world.yaml")

    # ── Single source of truth for the robot's spawn pose ────────────────────
    # The robot ALWAYS spawns at exactly this pose, AND AMCL is seeded here too,
    # so localization is correct on the first try with no manual "2D Pose
    # Estimate" -- the same trick multi-robot uses (spawn + seed both read the
    # same numbers, so they can't disagree).
    #
    # These are in the map frame, which coincides with the Gazebo world frame
    # for turtlebot3_world. (-2.0, -0.5, 0.0) is turtlebot3_world's standard,
    # obstacle-free spawn. If you rebuild the map or move the spawn and the robot
    # starts mislocalized: align it once in RViz, run
    #     ros2 topic echo /amcl_pose --once
    # and paste those x/y/yaw here -- spawn and seed then stay locked together.
    SPAWN_X, SPAWN_Y, SPAWN_YAW = -2.0, -0.5, 0.0

    declare_slam = DeclareLaunchArgument(
        "slam", default_value="False",
        description="True = map the world (drive to build a map); "
                    "False = localize in saved map + run the pipeline")
    declare_map = DeclareLaunchArgument(
        "map", default_value=default_map,
        description="Saved map yaml (used when slam:=False)")

    sim = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(bringup, "launch", "sim.launch.py")),
        launch_arguments={
            "x_pose": str(SPAWN_X),
            "y_pose": str(SPAWN_Y),
            "yaw": str(SPAWN_YAW),
        }.items())

    # nav2 bringup switches internally on `slam`:
    #   slam:=true  -> slam_toolbox + navigation (mapping)
    #   slam:=false -> map_server + amcl (localization in `map`) + navigation
    nav2_bringup = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(nav2, "launch", "bringup_launch.py")),
        launch_arguments={
            "use_sim_time": "true",
            "slam": slam,
            "map": map_yaml,
            "params_file": nav2_params,
        }.items())

    rviz = Node(
        package="rviz2", executable="rviz2", name="rviz2", output="screen",
        arguments=["-d", os.path.join(nav2, "rviz", "nav2_default_view.rviz")],
        parameters=[{"use_sim_time": True}])

    # Spine nodes run only in RUN mode (slam:=false), each in its own xterm.
    def xterm(pkg, exe, title, params=None):
        return Node(
            package=pkg, executable=exe, name=exe, output="screen",
            prefix=[f'xterm -T "{title}" -geometry 100x24 -hold -e'],
            parameters=params or [],
            condition=UnlessCondition(slam))

    interface = xterm("mission_interface", "prompt_publisher",
                      "1 INTERFACE  (type prompts here)")
    planner = xterm("mission_llm_planner", "llm_planner", "2 LLM PLANNER")
    validator = xterm("mission_validator", "mission_validator", "3 VALIDATOR",
                      [{"routes_file": routes_file}])
    executor = xterm("mission_executor", "mission_executor", "4 EXECUTOR",
                     [{"use_sim_time": True, "routes_file": routes_file}])

    # Delay so map_server + amcl + nav2 are active before the executor sends goals.
    spine = TimerAction(
        period=10.0, condition=UnlessCondition(slam),
        actions=[interface, planner, validator, executor])

    return LaunchDescription([
        declare_slam, declare_map, sim, nav2_bringup, rviz, spine,
    ])
