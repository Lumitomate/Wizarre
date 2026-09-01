# Issue tracker: GitHub

Issues et PRDs pour ce dépôt sont des issues GitHub. Utiliser la CLI `gh` pour toutes les opérations.

## Conventions

- **Créer une issue** : `gh issue create --title "..." --body "..."`
- **Lire une issue** : `gh issue view <numéro> --comments`
- **Lister les issues** : `gh issue list --state open` avec les filtres `--label` et `--state` appropriés
- **Commenter** : `gh issue comment <numéro> --body "..."`
- **Appliquer / retirer des étiquettes** : `gh issue edit <numéro> --add-label "..."` / `--remove-label "..."`
- **Fermer** : `gh issue close <numéro> --comment "..."`

## Pull requests comme surface de triage

**PRs comme surface de triage : oui.** Les PRs externes sont incluses dans la file de triage. Utiliser les équivalents `gh pr` : `gh pr view`, `gh pr list`, `gh pr comment`, `gh pr edit`, `gh pr close`.