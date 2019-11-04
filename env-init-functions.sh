#!/bin/bash -e

setup_conda() {
  MINICONDA_BASE_DIR=$(conda info --base)

  if [ ! -f "$HOME/.bashrc" ]; then
    touch "$HOME/.bashrc"
  fi

  # conda.sh not yet added to .bashrc
  if ! grep -q "/etc/profile.d/conda.sh" "$HOME/.bashrc"; then
    echo "Adding $MINICONDA_BASE_DIR/etc/profile.d/conda.sh to .bashrc"
    echo "source $MINICONDA_BASE_DIR/etc/profile.d/conda.sh" >> ~/.bashrc
  fi
}

prepare_environment() {
  if [ "$(cut -c 1-7 <<< "$(uname -s)")" == "MSYS_NT" ]; then
    echo "Wrong sh.exe in use, fix your PATH! Exiting..."
    exit 1
  fi

  if [ "$(cut -c 1-10 <<< "$(uname -s)")" == "MINGW64_NT" ]; then
    echo "Detected Windows OS"
    IS_WINDOWS=1
  else
    echo "Detected Unix-based OS"
    IS_WINDOWS=0
  fi

  CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

  if [ $IS_WINDOWS == 1 ]; then
    # /c/dir/subdir => c:/dir/subdir
    CURRENT_DIR=$(sed -r "s|^/([a-z])/|\1:/|" <<< $CURRENT_DIR)
  fi

  CONDA_ENV_PATH="$CURRENT_DIR/.venv"
}

create_conda_environment() {
  echo "Creating Conda environment to $CONDA_ENV_PATH"
  conda env create -f environment.yml -p "$CONDA_ENV_PATH"
}

install_new_conda_dependencies() {
  echo "Installing new Conda dependencies to $CONDA_ENV_PATH"
  conda env update -f environment.yml -p "$CONDA_ENV_PATH" --prune
}

install_poetry() {
  echo "Installing Poetry globally"
  curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py --silent -o "$CONDA_ENV_PATH/get-poetry.py"
  python "$CONDA_ENV_PATH/get-poetry.py" -y --version 1.0.0b3

  if [ $IS_WINDOWS == 1 ]; then
    export PATH="$HOME/.poetry/bin:$PATH"
  else
    source $HOME/.poetry/env
  fi
}

install_dependencies() {
  echo "Activating Conda environment"
  eval "$(conda shell.bash hook)"
  conda activate "$CONDA_ENV_PATH"

  # certifi cannot be updated by poetry (Cannot uninstall 'certifi'. It is a distutils installed project and thus we cannot accurately determine which files belong to it which would lead to only a partial uninstall.)
  # thus --ignore-installed is needed
  echo "Updating certifi"
  python -m pip install -U --ignore-installed certifi==2019.9.11

  # Installing dependencies from pyproject.toml
  poetry install --no-root
}

download_winutils_on_windows() {
  if [ $IS_WINDOWS == 1 ]; then
    echo "Downloading Hadoop winutils.exe"

    mkdir -p "$CONDA_ENV_PATH/hadoop/bin"
    curl https://raw.githubusercontent.com/steveloughran/winutils/master/hadoop-3.0.0/bin/winutils.exe --silent -o "$CONDA_ENV_PATH/hadoop/bin/winutils.exe"
  fi
}

set_conda_scripts() {
  echo "Setting up Conda activation & deactivation scripts"

  local CONDA_ACTIVATE_DIR="$CONDA_ENV_PATH/etc/conda/activate.d"
  mkdir -p $CONDA_ACTIVATE_DIR
  curl "https://raw.githubusercontent.com/DataSentics/dev-env-init/master/windows/conda/activate.d/env_vars.bat?$(date +%s)" --silent -o "$CONDA_ACTIVATE_DIR/env_vars.bat"
  curl "https://raw.githubusercontent.com/DataSentics/dev-env-init/master/unix/conda/activate.d/env_vars.sh?$(date +%s)" --silent -o "$CONDA_ACTIVATE_DIR/env_vars.sh"
  chmod +x "$CONDA_ACTIVATE_DIR/env_vars.sh"

  local CONDA_DEACTIVATE_DIR="$CONDA_ENV_PATH/etc/conda/deactivate.d"
  mkdir -p $CONDA_DEACTIVATE_DIR
  curl "https://raw.githubusercontent.com/DataSentics/dev-env-init/master/windows/conda/deactivate.d/env_vars.bat?$(date +%s)" --silent -o "$CONDA_DEACTIVATE_DIR/env_vars.bat"
  curl "https://raw.githubusercontent.com/DataSentics/dev-env-init/master/unix/conda/deactivate.d/env_vars.sh?$(date +%s)" --silent -o "$CONDA_DEACTIVATE_DIR/env_vars.sh"
  chmod +x "$CONDA_DEACTIVATE_DIR/env_vars.sh"
}

create_databricks_connect_config() {
    # .databricks-connect file must always exist (even empty) for the Databricks Connect to work properly
    # specific cluster connection credentials must be set when creating the SparkSession instance
    if [ ! -f ~/.databricks-connect ]; then
      echo "Creating empty .databricks-connect file"
      touch ~/.databricks-connect
    fi
}

show_installation_finished_info() {
  echo "---------------"

  echo "Setup completed. Active Conda environment now:"
  echo ""
  echo "conda activate $CONDA_ENV_PATH"
  echo ""
}

prepare_environment_databricks_app() {
  setup_conda
  prepare_environment

  if [ ! -d "$CONDA_ENV_PATH" ]; then
    create_conda_environment
    install_poetry
    install_dependencies
    download_winutils_on_windows
    set_conda_scripts
    create_databricks_connect_config
  else
    install_new_conda_dependencies
    install_poetry
    install_dependencies
  fi

  show_installation_finished_info
}

prepare_environment_for_package() {
  setup_conda
  prepare_environment

  if [ ! -d "$CONDA_ENV_PATH" ]; then
    create_conda_environment
    install_poetry
    install_dependencies
    set_conda_scripts
  else
    install_new_conda_dependencies
    install_poetry
    install_dependencies
  fi

  show_installation_finished_info
}
