#/bin/bash
set -eu
trap "pkill -P $$" EXIT

# Help text
help_command() {
  echo "Usage: $0 COMMAND"
  echo ""
  echo "Commands:"
  echo "  create     - Setting up the development environment(containers)"
  echo "  start      - Starting the development environment(containers), a existing fully set up set of containers must exist."
  echo "  stop       - Stopping but not removing the development environment(containers)"
  echo "  destroy    - Stopping and removing the development environment(containers)"
  echo "  runconfigs - Copies matching run configurations for Intellij and VS Code into the respective folders"
  echo "  help       - Print this help text"
}


# Create a clean development environment
create_command(){
  docker compose -p "" down
  docker buildx bake -f docker-compose.yml &
  docker compose -p "" pull &
  wait $(jobs -p)
  docker compose -p "" up -d --build
  ./.devcontainer/scripts/setupDevelopmentEnvironment.sh
}

# Start containers
start_command(){
  docker compose -p "" start
}

# Stop containers
stop_command(){
  docker compose -p "" stop
}

# Remove containers
destroy_command(){
  docker compose -p "" down
}

# Call Setup IDEs Script
runconfigs_command(){
  ./.devcontainer/scripts/setupIDEs.sh
  echo """
  # In case you want the recommended extentions for VSCode(needed for debug, follow code symbols etc.), execute:
  code --install-extension ms-azuretools.vscode-docker
  code --install-extension oderwat.indent-rainbow
  code --install-extension 2gua.rainbow-brackets
  code --install-extension KoichiSasada.vscode-rdbg
  code --install-extension Fooo.ruby-spec-runner
  code --install-extension castwide.solargraph
  code --install-extension eamodio.gitlens
  code --install-extension github.vscode-github-actions
  """
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

# Check Prerequisites
export should_exit=0
# Check Path Exists
for p in docker ruby bundle mysql psql yq; do
    if ! command -v "${p}" >/dev/null 2>&1; then
      echo "Error: Dependency \"$p\" is not installed" && export should_exit=1
    fi
done
# Check execution as ruby might set a shim
# shellcheck disable=SC2043
for p in uaac; do
    if ! eval "${p} --version" >/dev/null 2>&1; then
      echo "Error: Dependency \"$p\" is not installed" && export should_exit=1
    fi
done
if [ $should_exit != 0 ]; then
  exit 1
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
