#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# Suite headless en PARALLÈLE — même contrat que la boucle séquentielle de
# docs/agents/checks.md (chaque test se ferme seul, 0 = passe, 1 = échec).
#
# Usage : tests/parallel.sh [workers]     (4 par défaut)
#
# Un godot --headless --quit warm-up précède le lancement : il charge le
# projet complet et évite que les workers se marchent dessus en (ré)écrivant
# les caches de .godot au même moment. La suite ne tourne QU'UNE FOIS : le
# résultat est mis en mémoire tampon, affiché trié, puis compté.
# ─────────────────────────────────────────────────────────────────────────
set -u
cd "$(dirname "$0")/.."

WORKERS="${1:-4}"

godot --headless --quit > /dev/null 2>&1

resultats=$(mktemp)
trap 'rm -f "$resultats"' EXIT

printf '%s\n' tests/test_*.tscn | xargs -P "$WORKERS" -I{} sh -c '
	timeout 120 godot --headless "{}" > /dev/null 2>&1 \
		&& echo "pass  {}" || echo "ÉCHEC {}"
' | sort > "$resultats"

cat "$resultats"

echecs=$(grep -c "^ÉCHEC" "$resultats" || true)
passes=$(grep -c "^pass  " "$resultats" || true)
if [ "$echecs" -gt 0 ]; then
	echo "RESULT: FAIL ($echecs échec(s), $passes passés)"
	exit 1
fi
echo "RESULT: PASS ($passes tests)"
exit 0
