#/bin/bash
set -eu
trap "pkill -P $$" EXIT

# Prerequisits
# PSQL
# MYSQL
# RUBY(RBENV)
# RUBY BUNDLER
# UAAC (gem install cf-uaac)
# Docker
# Docker-Compose

# Help text
help_command() {
  echo "Usage: $0 COMMAND"
  echo ""
  echo "Commands:"
  echo "  create     - Setting up the development environment(containers)"
  echo "  start      - Starting the development environment(containers), a existing fully set up set of containers must exist."
  echo "  stop       - Stopping but not removing the development environment(containers)"
  echo "  destroy    - Stopping and removing the development environment(containers)"
  echo "  runconfigs - Copies matching run configurations for intellij and vscode into the respective folders"
  echo "  help       - Print this help text"
}


# Create a clean development environment
create_command(){
  docker-compose -p "" down
  docker buildx bake -f docker-compose.yml &
  docker-compose -p "" pull &
  wait $(jobs -p)
  docker-compose -p "" up -d
  ./.devcontainer/scripts/setupDevelopmentEnvironment.sh
}

# Start containers
start_command(){
  docker-compose -p "" start
}

# Stop containers
stop_command(){
  docker-compose -p "" stop
}

# Remove containers
destroy_command(){
  docker-compose -p "" down
}

# Call Setup IDEs Script
runconfigs_command(){
  ./.devcontainer/scripts/setupIDEs.sh
}

# Error handler
handle_error() {
  echo "Error: Invalid command"
  help_command
  exit 1
}

# Handle no command specified
if [ $# -eq 0 ]; then
  handle_error
fi

# Parse commands
case "$1" in
  create)
    echo "Setting up the development environment(containers)"
    create_command
    ;;
  start)
    echo "Starting the development environment(containers), a existing fully set up set of containers must exist."
    start_command
    ;;
  stop)
    echo "Stopping but not removing the development environment(containers)"
    stop_command
    ;;
  destroy)
    echo "Stopping and removing the development environment(containers)"
    destroy_command
    ;;
  runconfigs)
    echo "Copying matching run configurations for intellij and vscode into the respective folders"
    runconfigs_command
    ;;
  help)
    help_command
    ;;
  *)
    handle_error
    ;;
esac

trap "" EXIT