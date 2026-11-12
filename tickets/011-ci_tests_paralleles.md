# Ticket 011 — CI : exécuter les tests en parallèle, comme le local

## Statut : ready-for-agent

## Priorité : moyenne

## Contexte

Rétro de session : le test du magasin classique « flakait » uniquement
en local (`tests/parallel.sh`, 4 workers — anim basée temps réel, ticks
de physique en retard sous charge) et **jamais en CI** : `tests.yml`
exécute les tests SÉQUENTIELLEMENT. La CI prétend appliquer le même
contrat que le local mais n'exécute pas le même mode : un flake local
passe inaperçu côté CI, et la parité promise par `docs/agents/checks.md`
(« La CI lance la même boucle ») n'est pas vraie.

## Changement proposé

Dans `.github/workflows/tests.yml`, remplacer la boucle séquentielle par
l'appel au script existant :

```yaml
      - name: Run headless tests (parallel, same contract as local)
        run: tests/parallel.sh
```

Le script imprime déjà `RESULT: PASS/FAIL (n)` et sort avec le bon code
de sortie. Vérifier que le job remonte bien les sorties en cas d'échec
(parallel.sh affiche les lignes ÉCHEC, suffisant).

## Critères d'acceptation

- La CI lance `tests/parallel.sh` (4 workers par défaut).
- Un échec de test fait échouer le job avec les lignes ÉCHEC visibles.
- `docs/agents/checks.md` et le workflow racontent la même histoire
  (parallel des deux côtés, ou séquentiel des deux côtés — parallel
  recommandé : c'est le mode où les tests vivent localement).
