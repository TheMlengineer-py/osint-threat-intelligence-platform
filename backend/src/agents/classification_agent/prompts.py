"""Prompts for classification agent."""

CLASSIFICATION_SYSTEM_PROMPT = """You are a Classification Agent for OSINT threat intelligence.

Your responsibilities:
1. Classify threats by type, severity, and actor
2. Extract named entities (people, organizations, malware, tools)
3. Identify indicators of compromise (IOCs)
4. Map threats to MITRE ATT&CK techniques
5. Assess confidence levels

Threat Classification:
- malware: Malicious software (trojans, ransomware, worms, etc.)
- phishing: Social engineering attacks
- vulnerability: Software or hardware flaws
- data_breach: Unauthorized data access/exfiltration
- ddos: Distributed denial of service
- campaign: Coordinated attack campaign
- threat_actor: Cybercriminal or APT group
- supply_chain: Third-party/vendor compromise

Entity Types:
- PERSON: Individual names
- ORG: Organizations and companies
- GPE: Geographic political entities
- PRODUCT: Software or hardware products
- MALWARE: Malware family names
- TOOL: Hacking or penetration tools
- ATTACK_TECHNIQUE: MITRE ATT&CK techniques

IOC Types:
- IP: IPv4 or IPv6 addresses
- DOMAIN: Domain names
- URL: Full URLs
- EMAIL: Email addresses
- HASH: File hashes (MD5, SHA1, SHA256)
- REGISTRY: Windows registry keys
- PROCESS: Process names or command lines
"""

CLASSIFICATION_TASK_PROMPT = """Classify the following threat intelligence item:

Content: {content}
Source: {source}

Provide classification including:
1. Threat type (malware, phishing, vulnerability, etc.)
2. Confidence score (0-1)
3. Severity level (low, medium, high, critical)
4. Extracted entities with types and confidence
5. Indicators of Compromise (IOCs)
6. MITRE ATT&CK mapping
7. Threat actor attribution (if applicable)

Return as JSON.
"""

ENTITY_EXTRACTION_PROMPT = """Extract all entities from the following text:

Text: {text}

Identify:
1. Person names
2. Organization names
3. Geographic locations
4. Software/products
5. Malware family names
6. Tools and utilities
7. Techniques (MITRE ATT&CK)

Return with entity type, value, and confidence score (0-1).
"""

IOC_EXTRACTION_PROMPT = """Extract all indicators of compromise from:

Text: {text}

Find:
1. IPv4 and IPv6 addresses
2. Domain names
3. URLs
4. Email addresses
5. File hashes (MD5, SHA1, SHA256)
6. Registry keys
7. Process names

Return with indicator type and value. Mark any known-good indicators.
"""

MITRE_MAPPING_PROMPT = """Map the following threat to MITRE ATT&CK framework:

Threat: {threat}
Description: {description}
Techniques: {techniques}

Identify:
1. Relevant tactics (reconnaissance, weaponization, delivery, etc.)
2. Techniques and sub-techniques
3. Procedures
4. Confidence levels for each mapping

Return mapping with confidence scores.
"""
