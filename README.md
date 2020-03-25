# Python dev environment initialization

## Environment init: base steps

* Prepares the **Conda-based python dev environment** in the project's **.venv directory**
* Installs the [Poetry package manager](https://python-poetry.org/) into the user's home dir
* Installs all the dependencies defined in project's **poetry.lock** file
* Sets conda activation & deactivation scripts (mostly setting environment variables based on the project's **.env file**)
* Copies the project's **.env file** from the **.env.dist** template file

## Environment init: Databricks Connect specific steps

* Downloads **Java 1.8** binaries and puts them into the *~/.databricks-connect-java* dir
* Creates the empty *~/.databricks-connect* file
