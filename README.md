# Development environment initialization

for the [Pyfony framework](https://github.com/pyfony/pyfony)

### What it does:

* Prepares the **Conda-based python dev environment** in the project's **.venv directory**
* Installs the [Poetry package manager](https://python-poetry.org/) into the user's home dir
* Installs all the dependencies defined in project's **poetry.lock** file
* Sets conda activation & deactivation scripts (mostly setting environment variables based on the project's **.env file**)
* Copies the project's **.env file** from the **.env.dist** template file
* Adds `poetry install --no-root` to post-merge GIT hook 
