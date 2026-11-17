# devops-project

Petite API Node pour le lab DevOps.

`GET /health` répond `OK`.

## Lancer en local

```bash
npm install
npm start
```

Puis ouvrir http://localhost:3000/health

## Tests

```bash
npm test
npm run lint
```

## Docker

```bash
docker build -t myapp:0.1 .
docker run -d -p 3000:3000 --name myapp myapp:0.1
curl http://localhost:3000/health
```

L'image du lab est publiée sur GitHub Container Registry au merge sur `main`.

## Questions

**1. Pourquoi interdire les push directs sur main ?**

Si tout le monde peut pousser sur `main`, un commit peut arriver sans relecture et sans tests. Avec la protection, il faut une Pull Request. La CI tourne avant le merge, et quelqu'un d'autre peut regarder le diff.

**2. Différence entre une image et un conteneur**

L'image, c'est le résultat de `docker build` : un modèle figé, avec le système, Node et notre code. Le conteneur, c'est cette image démarrée. On a construit `myapp:0.1` une fois, puis lancé un conteneur nommé `myapp` avec `docker run`. On pourrait en lancer plusieurs à partir de la même image.

**3. Taille alpine et image complète**

`myapp:0.1`, basée sur `node:20-alpine`, fait 194 MB. La même application sur `node:20` fait 1,57 GB. Le serveur ne change pas. `node:20` embarque une Debian complète, Alpine ne garde que le minimum pour faire tourner Node.

**4. Pourquoi taguer l'image avec le SHA du commit, et pas `latest` ?**

`latest` est écrasé à chaque publication. On ne sait plus quel commit est derrière. Le SHA (`c33ee82…` pour le merge) désigne une seule version. On peut remonter de l'image au commit, puis au run Actions qui l'a publiée.

**5. Fail fast**

Le pipeline s'arrête à la première étape qui échoue. Quand le test attendait `KO` au lieu de `OK`, l'étape Tests a échoué et l'image n'a pas été construite ni publiée. On ne pousse pas plus loin un build déjà cassé.
