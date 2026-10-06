# Tableau de bord — Le marché des métiers marketing & digital

Site statique interactif construit à partir de `resume.json` (offres France Travail) et enrichi avec l'API publique [Recherche d'entreprises](https://recherche-entreprises.api.gouv.fr/docs/). Les analyses générales portent sur toute la base ; les analyses croisées indiquent leur couverture et n'utilisent que les offres dont l'entreprise a été rapprochée avec suffisamment de certitude.

## Enrichir les entreprises

Le script `enrich_offres.py` interroge l'API par nom d'entreprise, vérifie le département et privilégie une correspondance avec la commune de l'offre. Il conserve toutes les offres dans `offres_enrichies.json` et génère `enriched-data.js`, fichier compact chargé par `index.html`. Les offres sans nom ou sans correspondance restent visibles avec leur statut, sans inventer d'identifiant.

Pour actualiser les données et le badge manuellement avec Python 3.10 ou plus récent :

```sh
python3 update_data.py
```

`update_data.py` lance `enrich_offres.py`, puis inscrit l'heure locale de Paris dans le badge de `index.html`. Le script n'utilise que la bibliothèque standard Python. Si `python3` affiche une erreur indiquant que les outils développeur Xcode sont absents, lancez `xcode-select --install` dans le Terminal du Mac, puis vérifiez avec `python3 --version`.

## Ouvrir le tableau de bord

Double-cliquez sur `index.html` pour ouvrir le tableau de bord. Chart.js est chargé depuis jsDelivr ; une connexion internet est donc requise pour afficher les graphiques.

Pour servir le dossier localement :

```sh
ruby -run -e httpd . -p 8000
```

Puis ouvrez <http://localhost:8000>.

## Actualisation et publication

Le workflow `.github/workflows/update.yml` est planifié tous les jours à 05:00 UTC. Il exécute `update_data.py`, réinterroge Recherche d'entreprises pour les dénominations de `resume.json`, met à jour le badge, enregistre les changements et publie le site sur GitHub Pages. Il peut aussi être lancé manuellement depuis **Actions → Actualiser les données et publier le tableau de bord → Run workflow**.

Le workflow Pages `.github/workflows/pages.yml` publie également le site après les changements poussés sur `main`. Dans les réglages du dépôt GitHub, configurez **Settings → Pages → Build and deployment → GitHub Actions**.

Si ce dossier n'est pas encore relié à un dépôt GitHub, créez d'abord un dépôt vide sur GitHub, puis lancez dans ce dossier (en remplaçant l'adresse par celle du dépôt) :

```sh
git init -b main
git add .
git commit -m "Préparer le tableau de bord CM 2"
git remote add origin https://github.com/<compte>/<depot>.git
git push -u origin main
```

À ce stade, l'automatisation réactualise les données d'entreprises ; elle ne relance pas l'extraction France Travail. `resume.json` reste le dernier instantané présent dans le dépôt jusqu'à ce que la collecte France Travail soit actualisée séparément.

## Méthode de lecture

- Les graphiques globaux portent sur les offres de `resume.json`.
- Les graphiques d'entreprises ne portent que sur les rapprochements exacts avec un établissement dans le département de l'offre ; leur couverture est affichée au-dessus des graphiques.
- La taille croise la tranche d'effectif salarié publiée par l'API. Les codes APE sont présentés tels quels, sans prétendre déduire un libellé de secteur non fourni par l'API.
- Les salaires sont annualisés à partir des bornes présentes dans l'offre. Les moyennes par APE ne sont calculées que lorsque plusieurs salaires sont renseignés.
- Un écart de salaire par contrat, métier ou secteur reste descriptif : il ne contrôle pas l'expérience, la région ni le niveau de responsabilité.
