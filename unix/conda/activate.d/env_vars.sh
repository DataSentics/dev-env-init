#!/bin/bash
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_ROOT="$(sed "s|/\.venv/etc/conda/activate\.d$||" <<< $CURRENT_DIR)"

export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PROJECT_ROOT/src"

cd "$PROJECT_ROOT" || exit
