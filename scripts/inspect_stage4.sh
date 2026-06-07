#!/usr/bin/env bash
# Run from: backend/
# Usage: bash ../scripts/inspect_stage4.sh
echo "=== STAGE 4 FILE INSPECTION ==="
echo ""

for f in \
  src/intelligence/__init__.py \
  src/intelligence/classification/__init__.py \
  src/intelligence/classification/classifier.py \
  src/intelligence/entities/__init__.py \
  src/intelligence/entities/extractoe.py \
  src/intelligence/indicators/__init__.py \
  src/intelligence/indicators/ioc_extractor.py \
  src/agents/__init__.py \
  src/agents/base_agent.py \
  src/agents/classification_agent/__init__.py \
  src/agents/classification_agent/agent.py \
  src/agents/classification_agent/prompts.py \
  src/agents/classification_agent/tools.py \
  src/agents/risk_agent/__init__.py \
  src/agents/risk_agent/agent.py \
  src/agents/risk_agent/prompts.py \
  src/agents/risk_agent/tools.py \
  src/llm/ollama_client.py \
  src/preprocessing/cleaner.py \
  src/preprocessing/language_detector.py; do

  if [ -s "$f" ]; then
    echo "HAS CONTENT: $f ($(wc -l < $f) lines)"
  elif [ -f "$f" ]; then
    echo "EMPTY FILE:  $f"
  else
    echo "MISSING:     $f"
  fi
done

echo ""
echo "=== CONTENT OF NON-EMPTY FILES ==="
echo ""

for f in \
  src/intelligence/classification/classifier.py \
  src/intelligence/entities/extractoe.py \
  src/intelligence/indicators/ioc_extractor.py \
  src/agents/base_agent.py \
  src/agents/classification_agent/agent.py \
  src/agents/classification_agent/tools.py \
  src/agents/risk_agent/agent.py \
  src/agents/risk_agent/tools.py \
  src/llm/ollama_client.py; do

  if [ -s "$f" ]; then
    echo "=== $f ==="
    cat "$f"
    echo ""
  fi
done
