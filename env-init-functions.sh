#!/bin/bash -e

set +H

if [[ -z "$ENV_INIT_BRANCH" ]]; then ENV_INIT_BRANCH="master"; fi

add_conda_to_path() {
  if hash conda 2>/dev/null; then
    CONDA_EXECUTABLE_PATH="conda"
    echo "Using Conda executable from PATH"
    return 0
  fi

  if [ -f "$HOME/Miniconda3/Library/bin/conda.bat" ]; then
    CONDA_EXECUTABLE_PATH="$HOME/Miniconda3/Library/bin/conda.bat"
    source $HOME/Miniconda3/etc/profile.d/conda.sh

  elif [ -f "$HOME/Anaconda3/Library/bin/conda.bat" ]; then
    CONDA_EXECUTABLE_PATH="$HOME/Anaconda3/Library/bin/conda.bat"
    source $HOME/Anaconda3/etc/profile.d/conda.sh

  elif [ -f "$HOME/AppData/Local/Continuum/miniconda3/condabin/conda.bat" ]; then
    CONDA_EXECUTABLE_PATH="$HOME/AppData/Local/Continuum/miniconda3/condabin/conda.bat"
    source $HOME/AppData/Local/Continuum/miniconda3/etc/profile.d/conda.sh

  elif [ -f "$HOME/AppData/Local/Continuum/anaconda3/condabin/conda.bat" ]; then
    CONDA_EXECUTABLE_PATH="$HOME/AppData/Local/Continuum/anaconda3/condabin/conda.bat"
    source $HOME/AppData/Local/Continuum/anaconda3/etc/profile.d/conda.sh

  elif [ -f "$HOME/miniconda3/bin/conda" ]; then
    CONDA_EXECUTABLE_PATH="$HOME/miniconda3/bin/conda"
    source $HOME/miniconda3/etc/profile.d/conda.sh

  elif [ -f "$HOME/anaconda3/bin/conda" ]; then
    CONDA_EXECUTABLE_PATH="$HOME/anaconda3/bin/conda"
    source $HOME/anaconda3/etc/profile.d/conda.sh

  elif [ -f "$HOME/miniconda/bin/conda" ]; then
    CONDA_EXECUTABLE_PATH="$HOME/miniconda/bin/conda"
    source $HOME/miniconda/etc/profile.d/conda.sh

  elif [ -f "$HOME/anaconda/bin/conda" ]; then
    CONDA_EXECUTABLE_PATH="$HOME/anaconda/bin/conda"
    source $HOME/anaconda/etc/profile.d/conda.sh

  else
    echo "Unable to find Conda executable, exiting..."
    exit 1
  fi

  echo "Using Conda executable: $CONDA_EXECUTABLE_PATH"
}

setup_conda() {
  CONDA_BASE_DIR=$(conda info --base | sed 's/\\/\//g')

  echo "Using Conda base dir: $CONDA_BASE_DIR"

  if [ $IS_WINDOWS == 1 ]; then
    PYTHON_BASE_EXECUTABLE_PATH="$CONDA_BASE_DIR/python.exe"
    # c:/foo/bar -> /c/foo/bar
    PYTHON_ENV_EXECUTABLE_DIR=$(sed -r 's|^([a-zA-Z]):|/\1|g' <<< $CONDA_ENV_PATH)
  else
    PYTHON_BASE_EXECUTABLE_PATH="$CONDA_BASE_DIR/bin/python"
    PYTHON_ENV_EXECUTABLE_DIR="$CONDA_ENV_PATH/bin"
  fi

  if [ ! -f "$HOME/.bash_profile" ]; then
    echo "Creating .bash_profile"
    touch "$HOME/.bash_profile"
    echo "test -f ~/.profile && . ~/.profile" >> "$HOME/.bash_profile"
    echo "test -f ~/.bashrc && . ~/.bashrc" >> "$HOME/.bash_profile"
  fi

  if [ ! -f "$HOME/.bashrc" ]; then
    echo "Creating .bashrc"
    touch "$HOME/.bashrc"
  fi

  # conda.sh not yet added to .bashrc
  if ! grep -q "/etc/profile.d/conda.sh" "$HOME/.bashrc"; then
    echo "Adding $CONDA_BASE_DIR/etc/profile.d/conda.sh to .bashrc"
    echo "source $CONDA_BASE_DIR/etc/profile.d/conda.sh" >> ~/.bashrc
  fi

  echo "Creating ~/datasentics_env.sh"
  rm -f "$HOME/datasentics_env.sh"
  touch "$HOME/datasentics_env.sh"
  echo "alias ca='conda activate \$PWD/.venv'" >> ~/datasentics_env.sh

  if ! grep -q "datasentics_env.sh" "$HOME/.bashrc"; then
      echo "source ~/datasentics_env.sh added to ~/.bashrc"
      echo "source ~/datasentics_env.sh" >> ~/.bashrc
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
    DETECTED_OS="win"
  else
    echo "Detected Unix-based OS"
    IS_WINDOWS=0

    if [[ "$OSTYPE" == "darwin"* ]]; then
      DETECTED_OS="mac"
    else
      DETECTED_OS="linux"
    fi
  fi

  CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

  if [ $IS_WINDOWS == 1 ]; then
    # /c/dir/subdir => c:/dir/subdir
    CURRENT_DIR=$(sed -r "s|^/([a-z])/|\1:/|" <<< $CURRENT_DIR)
  fi

  if [ $DETECTED_OS == "mac" ]; then
    brew install libgit2
  fi

  CONDA_ENV_PATH="$CURRENT_DIR/.venv"

  add_conda_to_path
  setup_conda
}

create_conda_environment() {
  echo "Creating Conda environment to $CONDA_ENV_PATH"
  conda env create -f environment.yml -p "$CONDA_ENV_PATH"
}

install_poetry() {
  echo "Installing Poetry globally"
  curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py --silent -o "$CONDA_ENV_PATH/get-poetry.py"
  $PYTHON_BASE_EXECUTABLE_PATH "$CONDA_ENV_PATH/get-poetry.py" -y --version 1.0.0

  if [ $IS_WINDOWS == 1 ]; then
    # $HOME/.poetry/env does not exist on Windows
    export PATH="$HOME/.poetry/bin:$PATH"
  else
    source $HOME/.poetry/env
  fi
}

install_dependencies() {
  local POETRY_PATH
  POETRY_PATH=$(PATH="$PYTHON_ENV_EXECUTABLE_DIR:$PATH" where poetry | sed -n '1!p')
  echo "Using Poetry from: $POETRY_PATH"

  echo "Installing dependencies from poetry.lock"
  PATH="$PYTHON_ENV_EXECUTABLE_DIR:$PATH" poetry install --no-root
}

create_git_hooks() {
  local POST_MERGE_HOOK_PATH="$CURRENT_DIR/.git/hooks/post-merge"

  echo "Hooks path $POST_MERGE_HOOK_PATH"

  if [ ! -f "$POST_MERGE_HOOK_PATH" ]; then
    echo "Creating empty post-merge git hook"
    echo -e "#!/bin/sh\n\n" > "$POST_MERGE_HOOK_PATH"
  fi

  if ! grep -q "poetry install --no-root" "$POST_MERGE_HOOK_PATH"; then
    echo "Adding poetry install to post-merge git hook"
    echo "poetry install --no-root" >> "$POST_MERGE_HOOK_PATH"
  fi
}

download_winutils_on_windows() {
  if [ $IS_WINDOWS == 1 ]; then
    echo "Downloading Hadoop winutils.exe"

    mkdir -p "$CONDA_ENV_PATH/hadoop/bin"
    curl https://raw.githubusercontent.com/steveloughran/winutils/master/hadoop-3.0.0/bin/winutils.exe --silent > "$CONDA_ENV_PATH/hadoop/bin/winutils.exe"
  fi
}

set_conda_scripts() {
  echo "Setting up Conda activation & deactivation scripts"

  echo "Seting-up conda/activate.d"
  local CONDA_ACTIVATE_DIR="$CONDA_ENV_PATH/etc/conda/activate.d"
  mkdir -p $CONDA_ACTIVATE_DIR
  curl "https://raw.githubusercontent.com/DataSentics/dev-env-init/$ENV_INIT_BRANCH/unix/conda/activate.d/env_vars.sh?$(date +%s)" --silent > "$CONDA_ACTIVATE_DIR/env_vars.sh"
  chmod +x "$CONDA_ACTIVATE_DIR/env_vars.sh"

  echo "Seting-up conda/deactivate.d"
  local CONDA_DEACTIVATE_DIR="$CONDA_ENV_PATH/etc/conda/deactivate.d"
  mkdir -p $CONDA_DEACTIVATE_DIR
  curl "https://raw.githubusercontent.com/DataSentics/dev-env-init/$ENV_INIT_BRANCH/unix/conda/deactivate.d/env_vars.sh?$(date +%s)" --silent > "$CONDA_DEACTIVATE_DIR/env_vars.sh"
  chmod +x "$CONDA_DEACTIVATE_DIR/env_vars.sh"
}

download_java() {
  local JAVA_DIR="$HOME/.databricks-connect-java"

  if [ -d "$JAVA_DIR" ]; then
    echo "$JAVA_DIR already exists"
    return
  fi

  echo "Downloading Java 1.8 to $JAVA_DIR"

  mkdir -p $JAVA_DIR

  local JAVA_ZIP_DIR="$JAVA_DIR/jdk8u242-b08"

  if [ $IS_WINDOWS == 1 ]; then
    curl https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u242-b08/OpenJDK8U-jdk_x64_windows_hotspot_8u242b08.zip -L --silent > "$JAVA_DIR/java.zip"
    unzip -qq "$JAVA_DIR/java.zip" -d "$JAVA_DIR"
    mv "$JAVA_ZIP_DIR/"* $JAVA_DIR
    rm -rf "$JAVA_ZIP_DIR"
    rm -rf "$JAVA_DIR/java.zip"
    rm -rf "$JAVA_DIR/src.zip"
  elif [ $DETECTED_OS == "mac" ]; then
    curl https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u242-b08/OpenJDK8U-jdk_x64_mac_hotspot_8u242b08.tar.gz -L --silent > "$JAVA_DIR/java.tar.gz"
    tar -xzf "$JAVA_DIR/java.tar.gz" -C "$JAVA_DIR"
    mv "$JAVA_ZIP_DIR/Contents/Home/"* $JAVA_DIR
    rm -rf "$JAVA_ZIP_DIR"
    rm -rf "$JAVA_DIR/java.tar.gz"
    chmod +x "$CONDA_ENV_PATH/lib/python3.7/site-packages/pyspark/bin/"*
  elif [ $DETECTED_OS == "linux" ]; then
    curl https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u242-b08/OpenJDK8U-jdk_x64_linux_hotspot_8u242b08.tar.gz -L --silent > "$JAVA_DIR/java.tar.gz"
    tar -xzf "$JAVA_DIR/java.tar.gz" -C "$JAVA_DIR"
    mv "$JAVA_ZIP_DIR/"* $JAVA_DIR
    rm -rf "$JAVA_ZIP_DIR"
    rm -rf "$JAVA_DIR/java.tar.gz"
    chmod +x "$CONDA_ENV_PATH/lib/python3.7/site-packages/pyspark/bin/"*
  fi
}

create_databricks_connect_config() {
  # .databricks-connect file must always exist and contain at least empty JSON for the Databricks Connect to work properly
  # specific cluster connection credentials must be set when creating the SparkSession instance
  if [ ! -f "$HOME/.databricks-connect" ]; then
    echo "Creating empty .databricks-connect file"
    echo "{}" > "$HOME/.databricks-connect"
  fi
}

create_dot_env_file() {
  DOT_ENV_PATH="$CURRENT_DIR/.env"

  if [ ! -f "$DOT_ENV_PATH" ]; then
    if [ -f "$CURRENT_DIR/.env.dist" ]; then
      echo "Creating .env file from the .env.dist template"
      cp "$CURRENT_DIR/.env.dist" "$CURRENT_DIR/.env"
    else
      echo "Creating empty .env file in the project root"
      echo "APP_ENV=dev" > $DOT_ENV_PATH
    fi
  fi
}

show_installation_finished_info() {
  echo "---------------"

  echo "Setup completed. Active Conda environment now:"
  echo ""
  echo "conda activate $CONDA_ENV_PATH"
  echo ""
}

base_environment_setup() {
  prepare_environment

  if [ ! -d "$CONDA_ENV_PATH" ]; then
    echo "Creating new Conda environment"
    create_conda_environment
  fi

  install_poetry
  install_dependencies
  create_git_hooks
  set_conda_scripts
}

databricks_environment_setup() {
  download_winutils_on_windows
  download_java
  create_databricks_connect_config
}

# main invocation functions ---------------------

prepare_environment_databricks_app() {
  base_environment_setup
  databricks_environment_setup
  create_dot_env_file
  show_installation_finished_info
}

prepare_environment_for_package() {
  base_environment_setup
  show_installation_finished_info
}

prepare_environment_for_package_with_databricks() {
  base_environment_setup
  databricks_environment_setup
  show_installation_finished_info
}
