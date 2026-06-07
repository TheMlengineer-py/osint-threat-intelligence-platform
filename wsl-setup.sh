#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

print_success() { echo -e "${GREEN}[OK]${NC} \$1"; }
print_step() { echo -e "${CYAN}[+]${NC} \$1"; }

print_header "OSINT Platform - WSL2 Setup"

# Step 1: Check Python
print_header "Step 1: Checking Python"
PYTHON_CMD="python3.12"
if ! command -v $PYTHON_CMD &> /dev/null; then
    PYTHON_CMD="python3"
fi
print_success "Using: $PYTHON_CMD"
$PYTHON_CMD --version

# Step 2: Create venv
print_header "Step 2: Creating Virtual Environment"
if [ -d "venv" ]; then
    print_step "venv already exists, skipping..."
else
    print_step "Creating venv..."
    $PYTHON_CMD -m venv venv
    print_success "venv created"
fi

print_step "Activating venv..."
source venv/bin/activate
print_success "venv activated"

# Step 3: Install Python dependencies
print_header "Step 3: Installing Python Dependencies"
print_step "Upgrading pip..."
pip install -q --upgrade pip setuptools wheel
print_success "pip upgraded"

print_step "Installing requirements..."
if [ -f "backend/requirements.txt" ]; then
    pip install -q -r backend/requirements.txt
    print_success "Requirements installed"
else
    echo "backend/requirements.txt not found!"
    exit 1
fi

print_step "Downloading spaCy model..."
python -m spacy download en_core_web_sm >/dev/null 2>&1
print_success "spaCy ready"

# Step 4: Frontend
print_header "Step 4: Installing Frontend"
if [ -d "frontend/node_modules" ]; then
    print_step "node_modules exists, skipping..."
else
    print_step "Installing Node packages..."
    cd frontend
    npm install -q
    cd ..
    print_success "Frontend ready"
fi

# Step 5: PostgreSQL
print_header "Step 5: PostgreSQL Setup"
print_step "Starting PostgreSQL..."
sudo service postgresql start >/dev/null 2>&1
sleep 2
print_success "PostgreSQL started"

print_step "Creating database..."
sudo -u postgres psql -c "CREATE DATABASE osint_db;" 2>/dev/null || print_step "Database exists"
sudo -u postgres psql -c "CREATE USER osint_user WITH PASSWORD 'osint_password';" 2>/dev/null || print_step "User exists"
sudo -u postgres psql -d osint_db -c "GRANT ALL PRIVILEGES ON DATABASE osint_db TO osint_user;" 2>/dev/null
print_success "Database ready"

# Step 6: Migrations
print_header "Step 6: Running Migrations"
cd backend
alembic upgrade head >/dev/null 2>&1 && print_success "Migrations complete" || print_step "Migrations may need manual setup"
cd ..

# Done
print_header "Setup Complete!"
echo "Installed versions:"
python --version
node --version
npm --version
echo ""
echo "Next: ./start.sh all"
