#!/bin/sh
# FreeBSD flaresolverr launcher

FS_USER="flaresolverr"
if [ "$(whoami)" != "$FS_USER" ]; then
    echo "youre not $FS_USER"
    exit 1
fi

# REAPER: Only kill Chrome procs that have been orphaned (Parent PID is 1)
ps -U "$FS_USER" -o pid,ppid,comm | grep chrome | while read -r pid ppid FART; do
    if [ "$ppid" -eq 1 ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

FS_DIR="/usr/local/share/FlareSolverr"
DATA_DIR="/var/db/flaresolverr"
PYTHON_BIN="${FS_DIR}/venv/bin/python3"
SCRIPT_PATH="${FS_DIR}/src/flaresolverr.py"
PID_FILE="${DATA_DIR}/flaresolverr.pid"
XVFB_PID="${DATA_DIR}/xvfb.pid"
LOG_FILE="${DATA_DIR}/flaresolverr.log"

# LOG: ./flaresolverr.launcher.sh log
if [ "$1" = "log" ]; then
    LOG_DAEMON=" -o $LOG_FILE"
    set -x
fi

# STOP: ./flaresolverr.launcher.sh stop
if [ "$1" = "stop" ]; then
    echo "close all $FS_USER procs and clear pids etc"
    pkill -u "$FS_USER"
    [ -f "$PID_FILE" ] && kill $(cat "$PID_FILE") 2>/dev/null
    [ -f "$XVFB_PID" ] && kill $(cat "$XVFB_PID") 2>/dev/null
    rm -f "$PID_FILE" "$XVFB_PID" /tmp/.X99-lock /tmp/.tX99-unix/X99
    exit 0
fi

# START: ./flaresolverr.launcher.sh
# if we're running, exit:
if pgrep -f "flaresolverr.py" > /dev/null; then
    exit 0
fi

export BROWSER_PATH="/usr/local/bin/chrome"
export CHROMEDRIVER_PATH="/usr/local/bin/chromedriver"
export DISPLAY=":99"
export HOME="${DATA_DIR}"

# Ensure Xvfb is running
if ! pgrep -x "Xvfb" > /dev/null; then
    rm -f /tmp/.X99-lock
    daemon -u flaresolverr -p "$XVFB_PID" \
        /usr/local/bin/Xvfb :99 -screen 0 1024x768x16 > /dev/null 2>&1
    sleep 2
fi

daemon -f $LOG_DAEMON -p "$PID_FILE" "$PYTHON_BIN" "$SCRIPT_PATH"
