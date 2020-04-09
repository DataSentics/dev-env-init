#!/bin/bash
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_ROOT="$(sed "s|/\.venv/etc/conda/activate\.d$||" <<< $CURRENT_DIR)"

export PROJECT_ROOT
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PROJECT_ROOT/src"

unset SPARK_HOME

if [ -f "$PROJECT_ROOT/.env" ]; then
  set -o allexport; source "$PROJECT_ROOT/.env"; set +o allexport
fi

cd "$PROJECT_ROOT" || exit
