#!/bin/bash
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

print_header() { echo -e "\n${BLUE}$1${NC}\n"; }
print_success() { echo -e "${GREEN}[OK]${NC} \$1"; }

print_header "Render Deployment"

[ -d ".git" ] || { echo "Not a Git repository"; exit 1; }

print_success "Git repository found"

cat << 'INSTRUCTIONS'

RENDER DEPLOYMENT SETUP

1. Go to https://render.com and sign up with GitHub

2. Create Backend Service:
   - Click "New +" -> "Web Service"
   - Connect this GitHub repo
   - Environment: Docker
   - Add env vars: JWT_SECRET, ENVIRONMENT=production
   - Create PostgreSQL database and attach

3. Create Frontend Service:
   - Click "New +" -> "Static Site"
   - Build Command: cd frontend && npm run build
   - Publish Directory: frontend/dist
   - Add env var: VITE_API_URL=https://osint-backend.onrender.com

4. Push code:
   git add .
   git commit -m "your message"
   git push origin main

5. Services auto-deploy!

Access:
- Frontend: https://osint-frontend.onrender.com
- Backend: https://osint-backend.onrender.com

INSTRUCTIONS
