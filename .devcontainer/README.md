# Cloud Controller Development Environment

This document outlines how to set up and use the development environment for the Cloud Controller.

## Getting Started

1. **Prerequisites**: Ensure you have Docker and Visual Studio Code with the "Remote - Containers" extension installed.
2. **Launch the Environment**:
    * Open the `cloud_controller_ng` project folder in VS Code.
    * When prompted, click **"Reopen in Container"**. This will build the Docker images and start the development container. Also you can use the command palette (`Ctrl+Shift+P` or `Cmd+Shift+P` on macOS) and select **"Dev Containers: Reopen in Container"** or go to the remote explorer and select **"Reopen in Container"**.
    * The initial build may take some time as it installs all dependencies.

## Interacting with the Environment

Once the container is running, the startup script (`.devcontainer/scripts/codespaces_start.sh`) will automatically:

* Set up and seed the PostgreSQL and MariaDB databases.
* Configure the Cloud Controller application.
* Start all necessary services (UAA, Minio, Nginx, etc.).

## VS Code Launch Configurations

The `.vscode/launch.json` file contains several configurations for running and debugging different components of the Cloud Controller. You can access these from the "Run and Debug" panel in VS Code.

### Main Application

* **`[Postgres] CloudController`**: Runs the main Cloud Controller API using PostgreSQL as the database.
* **`[Mariadb] CloudController`**: Runs the main Cloud Controller API using MariaDB as the database.

> Note only one can be run at a time. Ensure the other is stopped before starting a new one.

### Workers & Scheduler

* **`[Postgres/Mariadb] CC Worker`**: Starts the generic background job worker against the respective database.
* **`[Postgres/Mariadb] CC Local Worker`**: Starts the local background job worker against the respective database.
* **`[Postgres/Mariadb] CC Scheduler`**: Starts the clock process for scheduling recurring tasks against the respective database.

> Note only one can be run at a time either against Postgres or Mysql. Ensure the other is stopped before starting a new one.

### Testing

* **`[Postgres/Mariadb] Unittests`**: Runs the complete RSpec test suite against the specified database.

### Cloud Foundry CLI

The environment comes pre-installed with the `cf8-cli` and `uaac`. You can interact with the local Cloud Foundry deployment from the VS Code terminal.

**API Endpoint**: `http://localhost:80`

**Admin Credentials**:

* **Username**: `ccadmin`
* **Password**: `secret`

**Example Login Workflow**:

1. **Target the API**:

    ```bash
    cf api http://localhost:80 --skip-ssl-validation
    ```

2. **Log In**:

    ```bash
    cf auth ccadmin secret
    ```

### PostgreSQL and MariaDB Access

You can connect directly to the databases running in the environment from the VS Code terminal.

#### PostgreSQL

* **Host**: `localhost`
* **Port**: `5432`
* **User**: `postgres`
* **Password**: `supersecret`

**Example Connection**:

```bash
PGPASSWORD=supersecret psql -h localhost -U postgres -d ccdb
```

#### MariaDB (MySQL)

* **Host**: `127.0.0.1`
* **Port**: `3306`
* **User**: `root`
* **Password**: `supersecret`

**Example Connection**:

```bash
mysql -h 127.0.0.1 -u root -psupersecret ccdb
```
