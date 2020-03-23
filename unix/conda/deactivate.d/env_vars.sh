#!/bin/bash

input="$PROJECT_ROOT/.env"

if [ -f "$input" ]; then
  while IFS= read -r line
  do
    if [[ "$line" =~ ^[^=]+=.+$ ]]; then
      VAR_TO_UNSET="$(echo "$line" | sed -E 's/^([^=]+)=.+$/\1/g')"

      if [ "$VAR_TO_UNSET" ]; then
        echo "Unseting $VAR_TO_UNSET"
        unset $VAR_TO_UNSET
      fi
    fi
  done < "$input"
fi

echo "Unseting PYTHONDONTWRITEBYTECODE"
unset PYTHONDONTWRITEBYTECODE

echo "Unseting CURRENT_DIR"
unset CURRENT_DIR

echo "Unseting PROJECT_ROOT"
unset PROJECT_ROOT

echo "Unseting PYTHONPATH"
unset PYTHONPATH
