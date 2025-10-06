#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Starting Org → HTML export"

# 🧩 Detect if running in GitHub Actions
IS_CI=${GITHUB_ACTIONS:-false}

# 🧠 Detect repo name automatically
if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  GITHUB_REPOSITORY=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/](.*)\.git#\1#' || echo "local/test-repo")
fi
REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

# 🌐 Detect base href
if [[ "$GITHUB_REPOSITORY" == *".github.io" ]]; then
  BASE_PATH="/"
else
  BASE_PATH="/$REPO_NAME/"
fi

echo "🌐 Detected base href: $BASE_PATH"

# 🧱 Ensure Emacs is available
if ! command -v emacs &>/dev/null; then
  if [[ "$IS_CI" == "true" ]]; then
    echo "🛠️ Installing Emacs in CI environment..."
    sudo apt-get update -y
    sudo apt-get install -y emacs-nox
  else
    echo "❌ Emacs not found. Please install Emacs."
    exit 1
  fi
else
  echo "✅ Emacs found: $(emacs --version | head -n 1)"
fi

# 🧱 Prepare output directory
rm -rf public
mkdir -p public

# 📂 Check for Org directory
if [[ ! -d org ]]; then
  echo "❌ No ./org directory found"
  exit 1
fi

echo "📂 Listing Org files:"
ls -la org/*.org 2>/dev/null || echo "No .org files found"

# 🔄 Export Org files
count=0
for f in org/*.org; do
  [ -e "$f" ] || { echo "⚠️ No .org files found"; break; }
  
  basename_file=$(basename "$f")
  output_file="${basename_file%.org}.html"
  
  echo "🧱 Exporting $f ..."
  
  # Export to HTML (will create in org/ directory by default)
  if emacs --batch \
        --eval "(require 'ox-html)" \
        --eval "(require 'ob)" \
        --eval "(org-babel-do-load-languages 'org-babel-load-languages '((emacs-lisp . t)))" \
        --eval "(setq org-confirm-babel-evaluate nil)" \
        --eval "(setq org-html-link-org-files-as-html t)" \
        --eval "(setq org-html-head \"<base href='${BASE_PATH}'><link rel='stylesheet' type='text/css' href='stylesheet.css'>\")" \
        --visit="$f" \
        --funcall org-html-export-to-html \
        2>&1 | grep -v "^Loading" || true; then
    
    # Move exported file from org/ to public/
    if [[ -f "org/${output_file}" ]]; then
      mv "org/${output_file}" "public/${output_file}"
      echo "✅ Exported: $f → public/$output_file"
      count=$((count + 1))
    else
      echo "❌ Failed to export $f (file not found after export)"
    fi
  else
    echo "❌ Emacs export failed for $f"
  fi
done

echo "📦 Total Org files exported: $count"
echo "🌐 Base href used for export: $BASE_PATH"

# 🎨 Copy stylesheet
echo "🎨 Copying stylesheet.css → public/"
if [[ -f stylesheet.css ]]; then
  cp stylesheet.css public/
  echo "✅ Copied stylesheet.css"
else
  echo "⚠️ No stylesheet.css found"
fi

# 🖼️ Copy assets
echo "🖼️ Copying assets from org/assets → public/assets/"
if [[ -d org/assets ]]; then
  mkdir -p public/assets
  if [[ -n "$(ls -A org/assets 2>/dev/null)" ]]; then
    cp -r org/assets/* public/assets/
    echo "✅ Assets copied"
  else
    echo "⚠️ Assets directory is empty"
  fi
else
  echo "⚠️ No assets directory found"
fi

# 🧾 Write manifest
echo "🧾 Writing manifest.txt"
{
  echo "Exported on: $(date -u)"
  echo "Repository: $GITHUB_REPOSITORY"
  echo "Base href: $BASE_PATH"
  echo
  echo "Files exported:"
  find public -type f | sort
} > public/manifest.txt

echo "✅ Org export complete."
echo ""
echo "📋 Summary:"
echo "   Exported files: $count"
echo "   Output directory: ./public/"
echo "   Base path: $BASE_PATH"

