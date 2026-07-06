#!/usr/bin/env bash
# Runs every time the ROS container starts, BEFORE the CMD (the ros2 launch).
set -e

# 1) Make ROS + our built workspace available in this shell.
source /opt/ros/jazzy/setup.bash
source /ws/install/setup.bash

# 2) Wait for the Ollama service to answer, then make sure the model is present.
#    OLLAMA_HOST is http://ollama:11434 (the compose service). We pull via the
#    HTTP API so we don't need the ollama CLI inside this container. The pull
#    streams progress; on subsequent runs the model is already cached, so this
#    returns almost immediately.
echo "[entrypoint] waiting for Ollama at ${OLLAMA_HOST} ..."
until curl -sf "${OLLAMA_HOST}/api/tags" >/dev/null 2>&1; do
  sleep 2
done
echo "[entrypoint] Ollama is up. Ensuring model '${LLM_MODEL}' is available ..."
curl -s "${OLLAMA_HOST}/api/pull" -d "{\"name\":\"${LLM_MODEL}\"}" \
  | grep -o '"status":"[^"]*"' | tail -n 1 || true
echo "[entrypoint] model ready."

# 3) Hand off to the container command (the ros2 launch, or a shell).
exec "$@"
