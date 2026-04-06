#!/usr/bin/env bash
# install.sh — lety-skill-hub marketplace installer
#
# Usage:
#   ./install.sh                     # list all available skills
#   ./install.sh <skill-name>        # install a skill by name
#   ./install.sh <skill-name> ...    # install multiple skills
#   ./install.sh --all               # install all skills
#
# Skills are installed to ~/.claude/skills/<skill-name>/

set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/skills" && pwd)"
INSTALL_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

# ── helpers ────────────────────────────────────────────────────────────────

list_skills() {
  echo -e "${BOLD}Available skills:${RESET}\n"
  while IFS= read -r skill_path; do
    local category skill description
    category=$(echo "$skill_path" | cut -d'/' -f1)
    skill=$(echo "$skill_path" | cut -d'/' -f2)
    description=$(grep -m1 '^description:' "$SKILLS_DIR/$skill_path/skill.md" 2>/dev/null \
      | sed 's/^description: *//' | sed 's/^"//' | sed 's/"$//' || echo "—")
    printf "  ${CYAN}%-28s${RESET} [%s]  %s\n" "$skill" "$category" "$description"
  done < <(find "$SKILLS_DIR" -name "skill.md" \
    | sed "s|$SKILLS_DIR/||" \
    | sed 's|/skill.md||' \
    | sort)
  echo ""
  echo -e "Install with: ${BOLD}./install.sh <skill-name>${RESET}"
}

install_skill() {
  local name="$1"
  local skill_path
  skill_path=$(find "$SKILLS_DIR" -type d -name "$name" | head -1)

  if [[ -z "$skill_path" ]]; then
    echo -e "${RED}✗ Skill '${name}' not found.${RESET}"
    echo "  Run ./install.sh to see available skills."
    return 1
  fi

  local dest="$INSTALL_DIR/$name"

  # Create install dir
  mkdir -p "$dest"

  # Copy all files from the skill directory
  cp -r "$skill_path/." "$dest/"

  # Claude Code requires SKILL.md (uppercase) — rename if needed
  if [[ -f "$dest/skill.md" && ! -f "$dest/SKILL.md" ]]; then
    mv "$dest/skill.md" "$dest/SKILL.md"
  fi

  echo -e "${GREEN}✓ Installed${RESET} ${BOLD}${name}${RESET} → ${dest}"
  echo -e "  Use it in Claude Code with: ${CYAN}/${name}${RESET}"
}

# ── main ───────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  list_skills
  exit 0
fi

if [[ "$1" == "--all" ]]; then
  echo -e "${BOLD}Installing all skills...${RESET}\n"
  while IFS= read -r skill_path; do
    skill=$(echo "$skill_path" | cut -d'/' -f2)
    install_skill "$skill"
  done < <(find "$SKILLS_DIR" -name "skill.md" \
    | sed "s|$SKILLS_DIR/||" \
    | sed 's|/skill.md||' \
    | sort)
  echo -e "\n${GREEN}Done.${RESET}"
  exit 0
fi

# Install each named skill
mkdir -p "$INSTALL_DIR"
failed=0
for skill_name in "$@"; do
  install_skill "$skill_name" || failed=1
done

exit $failed
