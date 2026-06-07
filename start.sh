#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VENV_PATH="$(pwd)/venv"
PROJECT_ROOT="$(pwd)"
PID_DIR="/tmp/osint_pids"

mkdir -p "$PID_DIR"

print_header() {
    echo -e "\n${BLUE}=> $1${NC}\n"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} \$1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} \$1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} \$1"
}

activate_venv() {
    if [ ! -f "$VENV_PATH/bin/activate" ]; then
        print_error "Virtual environment not found at $VENV_PATH"
        echo "Run: python3 -m venv venv"
        exit 1
    fi
    source "$VENV_PATH/bin/activate"
    print_success "Virtual environment activated"
}

init_backend_db() {
    print_header "Initializing Backend Database"

    cd "$PROJECT_ROOT/backend"

    # Create .env if missing
    if [ ! -f .env ]; then
        cat > .env << 'ENVFILE'
DATABASE_URL=sqlite:///./osint.db
SQLALCHEMY_ECHO=False
SECRET_KEY=dev-secret-key-change-in-production
ALGORITHM=HS256
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=mistral
REDIS_URL=redis://localhost:6379
LOG_LEVEL=INFO
API_V1_STR=/api/v1
PROJECT_NAME=OSINT Threat Intelligence Platform
FRONTEND_URL=http://localhost:5173
ENVFILE
        print_success ".env created"
    else
        print_warning ".env already exists"
    fi

    # Initialize database directly (skip alembic)
    python << 'DBPYTHON'
import sys
try:
    from src.database.engine import Base, engine
    print("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print("Database initialized successfully")
except Exception as e:
    print(f"Error initializing database: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
DBPYTHON

    print_success "Database ready"
    cd "$PROJECT_ROOT"
}

start_backend() {
    print_header "Starting Backend"

    # Check if port 8000 is in use
    if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_error "Port 8000 is already in use"
        return 1
    fi

    cd "$PROJECT_ROOT/backend"

    # Start backend in background
    uvicorn src.main:app --reload --host 0.0.0.0 --port 8000 > "$PID_DIR/backend.log" 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > "$PID_DIR/backend.pid"

    sleep 2

    if ps -p $BACKEND_PID > /dev/null; then
        print_success "Backend started (PID: $BACKEND_PID)"
        print_success "http://localhost:8000"
        print_success "API Docs: http://localhost:8000/docs"
        return 0
    else
        print_error "Failed to start backend"
        cat "$PID_DIR/backend.log"
        return 1
    fi
}

start_frontend() {
    print_header "Starting Frontend"

    # Check if port 5173 is in use
    if lsof -Pi :5173 -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_error "Port 5173 is already in use"
        return 1
    fi

    cd "$PROJECT_ROOT/frontend"

    # Install dependencies if needed
    if [ ! -d node_modules ]; then
        print_warning "Installing npm dependencies..."
        npm install --silent
        print_success "Dependencies installed"
    fi

    # Start frontend in background
    npm run dev > "$PID_DIR/frontend.log" 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > "$PID_DIR/frontend.pid"

    sleep 3

    if ps -p $FRONTEND_PID > /dev/null; then
        print_success "Frontend started (PID: $FRONTEND_PID)"
        print_success "http://localhost:5173"
        return 0
    else
        print_error "Failed to start frontend"
        cat "$PID_DIR/frontend.log"
        return 1
    fi
}

stop_services() {
    print_header "Stopping Services"

    if [ -f "$PID_DIR/backend.pid" ]; then
        BACKEND_PID=$(cat "$PID_DIR/backend.pid")
        if ps -p $BACKEND_PID > /dev/null 2>&1; then
            kill $BACKEND_PID 2>/dev/null || true
            print_success "Backend stopped"
        fi
        rm -f "$PID_DIR/backend.pid"
    fi

    if [ -f "$PID_DIR/frontend.pid" ]; then
        FRONTEND_PID=$(cat "$PID_DIR/frontend.pid")
        if ps -p $FRONTEND_PID > /dev/null 2>&1; then
            kill $FRONTEND_PID 2>/dev/null || true
            print_success "Frontend stopped"
        fi
        rm -f "$PID_DIR/frontend.pid"
    fi
}

show_status() {
    print_header "Service Status"

    if [ -f "$PID_DIR/backend.pid" ]; then
        BACKEND_PID=$(cat "$PID_DIR/backend.pid")
        if ps -p $BACKEND_PID > /dev/null 2>&1; then
            print_success "Backend running (PID: $BACKEND_PID) - http://localhost:8000"
        else
            print_error "Backend not running"
        fi
    else
        print_error "Backend not running"
    fi

    if [ -f "$PID_DIR/frontend.pid" ]; then
        FRONTEND_PID=$(cat "$PID_DIR/frontend.pid")
        if ps -p $FRONTEND_PID > /dev/null 2>&1; then
            print_success "Frontend running (PID: $FRONTEND_PID) - http://localhost:5173"
        else
            print_error "Frontend not running"
        fi
    else
        print_error "Frontend not running"
    fi
}

show_logs() {
    if [ "\$1" = "backend" ] || [ "\$1" = "all" ]; then
        echo ""
        echo -e "${BLUE}=== Backend Logs ===${NC}"
        if [ -f "$PID_DIR/backend.log" ]; then
            tail -20 "$PID_DIR/backend.log"
        else
            print_warning "No backend logs"
        fi
    fi

    if [ "\$1" = "frontend" ] || [ "\$1" = "all" ]; then
        echo ""
        echo -e "${BLUE}=== Frontend Logs ===${NC}"
        if [ -f "$PID_DIR/frontend.log" ]; then
            tail -20 "$PID_DIR/frontend.log"
        else
            print_warning "No frontend logs"
        fi
    fi
}

show_help() {
    echo "Usage: ./start.sh [command]"
    echo ""
    echo "Commands:"
    echo "  all              Start backend and frontend"
    echo "  backend          Start only backend"
    echo "  frontend         Start only frontend"
    echo "  stop             Stop all services"
    echo "  status           Show service status"
    echo "  logs             Show all logs"
    echo "  logs backend     Show backend logs"
    echo "  logs frontend    Show frontend logs"
    echo "  help             Show this help"
    echo ""
}

# Main logic
case "${1:-help}" in
    backend)
        activate_venv
        init_backend_db
        start_backend
        BACKEND_PID=$(cat "$PID_DIR/backend.pid")
        print_header "Backend running - Press Ctrl+C to stop"
        print_success "Logs: tail -f $PID_DIR/backend.log"
        wait $BACKEND_PID
        ;;

    frontend)
        cd "$PROJECT_ROOT/frontend"
        print_header "Starting Frontend"
        [ ! -d node_modules ] && npm install --silent
        print_success "http://localhost:5173"
        npm run dev
        ;;

    all)
        activate_venv
        init_backend_db

        print_header "Starting All Services"

        start_backend || exit 1
        start_frontend || exit 1

        echo ""
        echo -e "${GREEN}=====================================${NC}"
        echo -e "${GREEN}All Services Started Successfully${NC}"
        echo -e "${GREEN}=====================================${NC}"
        echo ""
        print_success "Backend: http://localhost:8000"
        print_success "Frontend: http://localhost:5173"
        print_success "API Docs: http://localhost:8000/docs"
        echo ""
        print_warning "Press Ctrl+C to stop or run: ./start.sh stop"
        echo ""

        # Wait for processes
        wait
        ;;

    stop)
        stop_services
        ;;

    status)
        show_status
        ;;

    logs)
        show_logs "${2:-all}"
        ;;

    help)
        show_help
        ;;

    *)
        print_error "Unknown command: \$1"
        echo ""
        show_help
        exit 1
        ;;
esac
