#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_PATH="${PROJECT_ROOT}/backend"

# Logging functions
log_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} \$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} \$1"
    exit 1
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} \$1"
}

# Start automation
log_header "OSINT Platform - Automated Setup (Steps 1-7)"

# Step 1: Fix Database Engine
log_header "Step 1: Fixing Database Engine Configuration"

cat > "${BACKEND_PATH}/src/database/engine.py" << 'EOF'
"""
Database Engine Configuration
"""

from sqlalchemy import create_engine, event
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.pool import StaticPool
import os
from urllib.parse import urlparse

# Get database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./osint.db")

# Check if using SQLite or PostgreSQL
is_sqlite = DATABASE_URL.startswith("sqlite")

if is_sqlite:
    # SQLite Configuration (Synchronous)
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=os.getenv("SQLALCHEMY_ECHO", "False").lower() == "true"
    )
else:
    # PostgreSQL Configuration (Asynchronous)
    engine = create_engine(
        DATABASE_URL,
        echo=os.getenv("SQLALCHEMY_ECHO", "False").lower() == "true"
    )

# Create declarative base
Base = declarative_base()

# Create session factory
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

def get_db():
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

log_success "Database engine fixed"

# Step 2: Fix Database Session
log_header "Step 2: Fixing Database Session Management"

cat > "${BACKEND_PATH}/src/database/session.py" << 'EOF'
"""
Database Session Management
"""

from sqlalchemy.orm import sessionmaker, Session
from src.database.engine import engine

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

def get_db() -> Session:
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

log_success "Database session fixed"

# Step 3: Update .env
log_header "Step 3: Creating/Updating .env File"

cat > "${BACKEND_PATH}/.env" << 'EOF'
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
EOF

log_success ".env file created"

# Step 4: Update start.sh
log_header "Step 4: Updating start.sh Script"

cat > "${PROJECT_ROOT}/start.sh" << 'EOF'
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
EOF

chmod +x "${PROJECT_ROOT}/start.sh"
log_success "start.sh updated"

# Step 5: Create Data Collectors
log_header "Step 5: Creating Data Collectors"

# CISA Collector
cat > "${BACKEND_PATH}/src/ingestion/cisa_collector.py" << 'EOF'
"""
CISA Cybersecurity Advisories Collector
Fetches latest CVE vulnerabilities from CISA/NVD
"""

import asyncio
import aiohttp
import logging
from datetime import datetime
from typing import List, Dict, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class CISAThreat:
    """Represents a CISA vulnerability"""
    cve_id: str
    title: str
    description: str
    severity: str
    cvss_score: Optional[float]
    published_date: str
    source_url: str
    affected_products: List[str]

    def to_dict(self) -> dict:
        return {
            'external_id': self.cve_id,
            'title': self.title,
            'description': self.description,
            'severity': self.severity,
            'confidence_score': self.cvss_score or 0.0,
            'published_date': self.published_date,
            'source': 'CISA',
            'source_url': self.source_url,
            'threat_type': 'VULNERABILITY',
            'status': 'NEW'
        }

class CISACollector:
    """Collect CVE data from CISA/NVD API"""

    BASE_URL = "https://services.nvd.nist.gov/rest/json/cves/2.0"

    def __init__(self, timeout: int = 30):
        self.timeout = aiohttp.ClientTimeout(total=timeout)

    async def collect_latest_threats(self, limit: int = 50) -> List[CISAThreat]:
        """Fetch latest CVE vulnerabilities"""
        threats = []

        try:
            async with aiohttp.ClientSession(timeout=self.timeout) as session:
                url = f"{self.BASE_URL}?resultsPerPage={limit}"

                async with session.get(url) as response:
                    if response.status == 200:
                        data = await response.json()

                        for vuln in data.get('vulnerabilities', []):
                            threat = self._parse_vulnerability(vuln)
                            if threat:
                                threats.append(threat)

                        logger.info(f"Collected {len(threats)} threats from CISA")
                    else:
                        logger.error(f"CISA API returned status {response.status}")

        except Exception as e:
            logger.error(f"Error fetching CISA data: {e}")

        return threats

    def _parse_vulnerability(self, vuln: dict) -> Optional[CISAThreat]:
        """Parse a single CVE vulnerability"""
        try:
            vuln_data = vuln.get('cve', {})
            cve_id = vuln_data.get('id', '').strip()

            if not cve_id:
                return None

            metrics = vuln_data.get('metrics', {})
            cvss_v3 = metrics.get('cvssMetricV31', [{}])[0]
            severity = cvss_v3.get('cvssData', {}).get('baseSeverity', 'UNKNOWN')
            cvss_score = cvss_v3.get('cvssData', {}).get('baseScore')

            descriptions = vuln_data.get('descriptions', [])
            description = descriptions[0].get('value', '') if descriptions else 'No description'

            threat = CISAThreat(
                cve_id=cve_id,
                title=cve_id,
                description=description[:500],
                severity=severity,
                cvss_score=cvss_score,
                published_date=vuln_data.get('published', ''),
                source_url=f"https://nvd.nist.gov/vuln/detail/{cve_id}",
                affected_products=[]
            )

            return threat

        except Exception as e:
            logger.error(f"Error parsing vulnerability: {e}")
            return None

if __name__ == "__main__":
    async def main():
        collector = CISACollector()
        threats = await collector.collect_latest_threats(limit=10)
        print(f"Collected {len(threats)} threats")
        for threat in threats[:3]:
            print(f"  {threat.cve_id}: {threat.severity}")

    asyncio.run(main())
EOF

log_success "CISA Collector created"

# NewsAPI Collector
cat > "${BACKEND_PATH}/src/ingestion/newsapi_collector.py" << 'EOF'
"""
NewsAPI Collector for threat-related news articles
"""

import asyncio
import aiohttp
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class NewsItem:
    """Represents a news article"""
    title: str
    description: str
    source: str
    published_date: str
    source_url: str
    content: str = ""

    def to_dict(self) -> dict:
        return {
            'title': self.title,
            'description': self.description,
            'source': self.source,
            'published_date': self.published_date,
            'source_url': self.source_url,
            'threat_type': 'NEWS',
            'status': 'NEW',
            'severity': 'MEDIUM'
        }

class NewsAPICollector:
    """Collect threat-related news from NewsAPI"""

    BASE_URL = "https://newsapi.org/v2/everything"
    API_KEY = "demo"

    def __init__(self, timeout: int = 30):
        self.timeout = aiohttp.ClientTimeout(total=timeout)

    async def collect_threat_news(self, days: int = 7, limit: int = 50) -> List[NewsItem]:
        """Fetch threat-related news articles"""
        articles = []

        search_terms = [
            'cybersecurity threat',
            'data breach',
            'malware',
            'ransomware',
            'vulnerability',
            'hacking',
            'cyber attack'
        ]

        try:
            async with aiohttp.ClientSession(timeout=self.timeout) as session:
                for term in search_terms:
                    articles.extend(
                        await self._search_term(session, term, days, limit)
                    )
                    await asyncio.sleep(1)

            logger.info(f"Collected {len(articles)} news articles")

        except Exception as e:
            logger.error(f"Error fetching news: {e}")

        return articles

    async def _search_term(
        self,
        session: aiohttp.ClientSession,
        term: str,
        days: int,
        limit: int
    ) -> List[NewsItem]:
        """Search for a specific term"""
        articles = []

        try:
            from_date = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d')

            params = {
                'q': term,
                'from': from_date,
                'sortBy': 'publishedAt',
                'language': 'en',
                'pageSize': min(limit, 100),
                'apiKey': self.API_KEY
            }

            async with session.get(self.BASE_URL, params=params) as response:
                if response.status == 200:
                    data = await response.json()

                    for article in data.get('articles', []):
                        try:
                            item = NewsItem(
                                title=article.get('title', ''),
                                description=article.get('description', ''),
                                source=article.get('source', {}).get('name', 'Unknown'),
                                published_date=article.get('publishedAt', ''),
                                source_url=article.get('url', ''),
                                content=article.get('content', '')
                            )
                            articles.append(item)
                        except Exception as e:
                            logger.error(f"Error parsing article: {e}")
                            continue

                    logger.debug(f"Found {len(articles)} articles for '{term}'")
                else:
                    logger.error(f"NewsAPI returned status {response.status}")

        except Exception as e:
            logger.error(f"Error searching for '{term}': {e}")

        return articles

if __name__ == "__main__":
    async def main():
        collector = NewsAPICollector()
        articles = await collector.collect_threat_news(days=7, limit=20)
        print(f"Collected {len(articles)} articles")
        for article in articles[:3]:
            print(f"  {article.source}: {article.title[:60]}")

    asyncio.run(main())
EOF

log_success "NewsAPI Collector created"

# RSS Collector
cat > "${BACKEND_PATH}/src/ingestion/rss_collector.py" << 'EOF'
"""
RSS Feed Collector for threat intelligence feeds
"""

import asyncio
import feedparser
import logging
from datetime import datetime
from typing import List, Dict
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class RSSItem:
    """Represents an RSS feed item"""
    title: str
    description: str
    source: str
    published_date: str
    source_url: str
    feed_name: str

    def to_dict(self) -> dict:
        return {
            'title': self.title,
            'description': self.description,
            'source': self.source,
            'published_date': self.published_date,
            'source_url': self.source_url,
            'threat_type': 'NEWS',
            'status': 'NEW',
            'severity': 'MEDIUM'
        }

class RSSCollector:
    """Collect threat intelligence from RSS feeds"""

    THREAT_FEEDS = {
        'CISA_Alerts': 'https://www.cisa.gov/feed/alerts.xml',
        'Bleeping_Computer': 'https://www.bleepingcomputer.com/feed/',
        'Dark_Reading': 'https://www.darkreading.com/feed',
        'SecurityWeek': 'https://www.securityweek.com/feed/',
    }

    def __init__(self):
        self.timeout = 30

    async def collect_from_all_feeds(self, limit: int = 50) -> List[RSSItem]:
        """Collect from all configured feeds"""
        all_items = []

        for feed_name, feed_url in self.THREAT_FEEDS.items():
            try:
                logger.info(f"Collecting from {feed_name}...")
                items = await self._collect_from_feed(feed_url, feed_name, limit)
                all_items.extend(items)
                await asyncio.sleep(0.5)
            except Exception as e:
                logger.error(f"Error collecting from {feed_name}: {e}")

        logger.info(f"Collected {len(all_items)} items from all feeds")
        return all_items

    async def _collect_from_feed(
        self,
        feed_url: str,
        feed_name: str,
        limit: int
    ) -> List[RSSItem]:
        """Collect items from a single RSS feed"""
        items = []

        try:
            loop = asyncio.get_event_loop()
            feed = await loop.run_in_executor(
                None,
                feedparser.parse,
                feed_url
            )

            if not feed.entries:
                logger.warning(f"No entries found in {feed_name}")
                return items

            for entry in feed.entries[:limit]:
                try:
                    item = RSSItem(
                        title=entry.get('title', 'No title'),
                        description=entry.get('summary', ''),
                        source=feed_name,
                        published_date=entry.get('published', datetime.now().isoformat()),
                        source_url=entry.get('link', ''),
                        feed_name=feed_name
                    )
                    items.append(item)
                except Exception as e:
                    logger.error(f"Error parsing entry from {feed_name}: {e}")
                    continue

            logger.debug(f"Collected {len(items)} items from {feed_name}")

        except Exception as e:
            logger.error(f"Error parsing feed {feed_name}: {e}")

        return items

if __name__ == "__main__":
    async def main():
        collector = RSSCollector()
        items = await collector.collect_from_all_feeds(limit=20)
        print(f"Collected {len(items)} items")
        for item in items[:5]:
            print(f"  [{item.source}] {item.title[:60]}")

    asyncio.run(main())
EOF

log_success "RSS Collector created"

# Step 6: Create Ingestion Service
log_header "Step 6: Creating Ingestion Service"

cat > "${BACKEND_PATH}/src/services/ingestion_service.py" << 'EOF'
"""
Ingestion Service - Orchestrates data collection from all sources
"""

import asyncio
import logging
from datetime import datetime
from typing import Dict

from sqlalchemy.orm import Session

from src.ingestion.cisa_collector import CISACollector
from src.ingestion.newsapi_collector import NewsAPICollector
from src.ingestion.rss_collector import RSSCollector
from src.models.orm.threat import Threat
from src.database.session import SessionLocal

logger = logging.getLogger(__name__)

class IngestionService:
    """Orchestrate threat data ingestion from multiple sources"""

    def __init__(self, db: Session = None):
        self.db = db or SessionLocal()

    async def ingest_all_sources(self) -> Dict[str, int]:
        """Collect and store threats from all sources"""
        results = {
            'cisa': 0,
            'news': 0,
            'rss': 0,
            'total': 0,
            'errors': 0
        }

        try:
            logger.info("Starting CISA collection...")
            cisa_collector = CISACollector()
            cisa_threats = await cisa_collector.collect_latest_threats(limit=50)
            results['cisa'] = await self._store_threats(cisa_threats)

            logger.info("Starting NewsAPI collection...")
            news_collector = NewsAPICollector()
            news_items = await news_collector.collect_threat_news(days=7, limit=50)
            results['news'] = await self._store_news_items(news_items)

            logger.info("Starting RSS collection...")
            rss_collector = RSSCollector()
            rss_items = await rss_collector.collect_from_all_feeds(limit=50)
            results['rss'] = await self._store_rss_items(rss_items)

            results['total'] = results['cisa'] + results['news'] + results['rss']

            logger.info(
                f"Ingestion complete: CISA={results['cisa']}, "
                f"News={results['news']}, RSS={results['rss']}, Total={results['total']}"
            )

        except Exception as e:
            logger.error(f"Error in ingestion: {e}")
            results['errors'] += 1

        return results

    async def _store_threats(self, threats) -> int:
        """Store CISA threats in database"""
        count = 0

        for threat_data in threats:
            try:
                existing = self.db.query(Threat).filter(
                    Threat.external_id == threat_data.cve_id
                ).first()

                if existing:
                    logger.debug(f"Threat {threat_data.cve_id} already exists")
                    continue

                threat = Threat(
                    title=threat_data.title,
                    description=threat_data.description,
                    threat_type='VULNERABILITY',
                    severity=threat_data.severity,
                    confidence_score=threat_data.cvss_score or 0.0,
                    published_date=threat_data.published_date,
                    source='CISA',
                    source_url=threat_data.source_url,
                    external_id=threat_data.cve_id,
                    status='NEW'
                )

                self.db.add(threat)
                count += 1

            except Exception as e:
                logger.error(f"Error storing threat {threat_data.cve_id}: {e}")

        self.db.commit()
        return count

    async def _store_news_items(self, items) -> int:
        """Store news items as threats"""
        count = 0

        for item in items:
            try:
                existing = self.db.query(Threat).filter(
                    Threat.source_url == item.source_url
                ).first()

                if existing:
                    logger.debug(f"News item {item.title} already exists")
                    continue

                threat = Threat(
                    title=item.title,
                    description=item.description,
                    threat_type='NEWS',
                    severity='MEDIUM',
                    confidence_score=0.7,
                    published_date=item.published_date,
                    source='NewsAPI',
                    source_url=item.source_url,
                    status='NEW'
                )

                self.db.add(threat)
                count += 1

            except Exception as e:
                logger.error(f"Error storing news item: {e}")

        self.db.commit()
        return count

    async def _store_rss_items(self, items) -> int:
        """Store RSS items as threats"""
        count = 0

        for item in items:
            try:
                existing = self.db.query(Threat).filter(
                    Threat.source_url == item.source_url
                ).first()

                if existing:
                    logger.debug(f"RSS item {item.title} already exists")
                    continue

                threat = Threat(
                    title=item.title,
                    description=item.description,
                    threat_type='NEWS',
                    severity='MEDIUM',
                    confidence_score=0.7,
                    published_date=item.published_date,
                    source=item.source,
                    source_url=item.source_url,
                    status='NEW'
                )

                self.db.add(threat)
                count += 1

            except Exception as e:
                logger.error(f"Error storing RSS item: {e}")

        self.db.commit()
        return count

    def __del__(self):
        if self.db:
            self.db.close()

if __name__ == "__main__":
    async def main():
        service = IngestionService()
        results = await service.ingest_all_sources()

        print("\n" + "="*50)
        print("INGESTION RESULTS")
        print("="*50)
        print(f"CISA threats: {results['cisa']}")
        print(f"News items: {results['news']}")
        print(f"RSS items: {results['rss']}")
        print(f"Total ingested: {results['total']}")
        print(f"Errors: {results['errors']}")
        print("="*50 + "\n")

    asyncio.run(main())
EOF

log_success "Ingestion Service created"

# Step 7: Create API Routes and Schemas
log_header "Step 7: Creating API Routes and Schemas"

# Threat Schema
cat > "${BACKEND_PATH}/src/api/schemas/threat_schemas.py" << 'EOF'
"""
Threat API Schemas
"""

from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class ThreatCreate(BaseModel):
    title: str
    description: Optional[str] = None
    threat_type: str
    severity: str
    source: str

class ThreatResponse(BaseModel):
    id: int
    external_id: Optional[str] = None
    title: str
    description: Optional[str] = None
    threat_type: str
    severity: str
    confidence_score: float
    source: str
    source_url: Optional[str] = None
    published_date: Optional[datetime] = None
    created_at: datetime
    status: str

    class Config:
        from_attributes = True

class ThreatListResponse(BaseModel):
    total: int
    threats: List[ThreatResponse]
EOF

log_success "Threat Schema created"

# Threat Routes
cat > "${BACKEND_PATH}/src/api/routes/threats.py" << 'EOF'
"""
Threat Intelligence API Routes
"""

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Dict
from datetime import datetime

from src.api.dependencies.database import get_db
from src.api.schemas.threat_schemas import ThreatResponse, ThreatCreate
from src.models.orm.threat import Threat
from src.services.ingestion_service import IngestionService
import asyncio

router = APIRouter(prefix="/api/v1/threats", tags=["threats"])

@router.get("/", response_model=List[ThreatResponse])
async def get_threats(
    skip: int = 0,
    limit: int = 50,
    severity: str = None,
    threat_type: str = None,
    db: Session = Depends(get_db)
):
    """Get all threats with optional filtering"""
    query = db.query(Threat).order_by(Threat.created_at.desc())

    if severity:
        query = query.filter(Threat.severity == severity)

    if threat_type:
        query = query.filter(Threat.threat_type == threat_type)

    threats = query.offset(skip).limit(limit).all()
    return threats

@router.post("/ingest", response_model=dict)
async def ingest_threats(background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """Trigger data ingestion from all sources"""
    try:
        def run_ingestion():
            async def async_ingest():
                service = IngestionService(db)
                return await service.ingest_all_sources()

            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            return loop.run_until_complete(async_ingest())

        background_tasks.add_task(run_ingestion)

        return {
            "status": "success",
            "message": "Ingestion started in background",
            "result": None
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/ingest/status", response_model=dict)
async def ingest_status(db: Session = Depends(get_db)):
    """Get ingestion statistics"""
    total = db.query(Threat).count()
    critical = db.query(Threat).filter(Threat.severity == "CRITICAL").count()
    high = db.query(Threat).filter(Threat.severity == "HIGH").count()
    medium = db.query(Threat).filter(Threat.severity == "MEDIUM").count()

    return {
        "total_threats": total,
        "critical": critical,
        "high": high,
        "medium": medium,
        "last_updated": datetime.utcnow().isoformat()
    }

@router.get("/{threat_id}", response_model=ThreatResponse)
async def get_threat(threat_id: int, db: Session = Depends(get_db)):
    """Get specific threat by ID"""
    threat = db.query(Threat).filter(Threat.id == threat_id).first()

    if not threat:
        raise HTTPException(status_code=404, detail="Threat not found")

    return threat

@router.get("/stats/summary", response_model=dict)
async def get_threat_stats(db: Session = Depends(get_db)):
    """Get threat statistics by type and severity"""
    stats = {
        'by_severity': {},
        'by_type': {},
        'by_source': {}
    }

    for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
        count = db.query(Threat).filter(Threat.severity == severity).count()
        stats['by_severity'][severity] = count

    types = db.query(Threat.threat_type, func.count(Threat.id)).group_by(Threat.threat_type).all()
    for threat_type, count in types:
        stats['by_type'][threat_type] = count

    sources = db.query(Threat.source, func.count(Threat.id)).group_by(Threat.source).all()
    for source, count in sources:
        stats['by_source'][source] = count

    return stats
EOF

log_success "Threat Routes created"

# Complete
log_header "Setup Complete!"

echo -e "${GREEN}All files have been created/updated:${NC}"
echo ""
echo "  [Step 1] Database Engine Configuration"
echo "  [Step 2] Database Session Management"
echo "  [Step 3] Environment Variables (.env)"
echo "  [Step 4] Start Script (start.sh)"
echo "  [Step 5] Data Collectors (CISA, NewsAPI, RSS)"
echo "  [Step 6] Ingestion Service"
echo "  [Step 7] API Routes and Schemas"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "  1. Navigate to project root:"
echo "     cd /mnt/c/Users/playground/OSINT/osint-threat-intelligence-platform"
echo ""
echo "  2. Activate venv and start backend:"
echo "     source venv/bin/activate"
echo "     ./start.sh backend"
echo ""
echo "  3. In another terminal, trigger ingestion:"
echo "     curl -X POST http://localhost:8000/api/v1/threats/ingest"
echo ""
echo "  4. Check results:"
echo "     curl http://localhost:8000/api/v1/threats"
echo "     curl http://localhost:8000/api/v1/threats/stats/summary"
echo ""

log_success "Automation complete"
