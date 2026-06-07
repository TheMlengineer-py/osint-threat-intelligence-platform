#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

VENV_PATH="$(pwd)/venv"

print_header() { echo -e "\n${BLUE}$1${NC}\n"; }
print_success() { echo -e "${GREEN}[OK]${NC} \$1"; }

activate_venv() {
    [ -f "$VENV_PATH/bin/activate" ] || { echo "Run: bash wsl-setup.sh"; exit 1; }
    source "$VENV_PATH/bin/activate"
}

case "${1:-backend}" in
    backend)
        print_header "Backend Tests"
        activate_venv
        cd backend && pytest tests/ -v --tb=short
        print_success "Tests passed"
        ;;
    frontend)
        print_header "Frontend Tests"
        cd frontend && npm test
        print_success "Tests passed"
        ;;
    *)
        echo "Usage: ./test.sh [backend|frontend]"
        exit 1
        ;;
esac
