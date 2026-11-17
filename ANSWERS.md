# Session 2 - reponses

Auteurs :
- Ruben Bensais Rueda
- Kais Luce Laurent
- Sami Semallai

## 1. Role d'un namespace ?

Ca sert a ranger les objets dans le cluster. On a mis `dev`, `staging` et `prod`, chacun avec son Service `myapp`, sans collision de noms. Par contre ca n'isole pas vraiment au niveau secu. Sans NetworkPolicy / RBAC, un pod d'un namespace peut encore parler a un autre. Pour une vraie isolation il faut ca, ou des clusters separes.

## 2. Pourquoi le pod revient apres un delete ?

Parce que le Deployment demande 3 replicas. Le ReplicaSet voit qu'il en manque un et en recree un. C'est le controleur ReplicaSet qui fait ca, pas magique.

## 3. Readiness vs liveness

Readiness = est-ce que le pod peut recevoir du trafic. Si ca rate, le Service l'enleve des endpoints, mais le process continue. Liveness = est-ce que le conteneur est encore vivant. Si ca rate, kubelet le restart. Quand on a mis le chemin `/nope`, on a vu Ready=False et des events Unhealthy dans `kubectl describe`.

## 4. Les Secrets sont chiffres ?

Non, par defaut c'est surtout du base64 dans etcd. Quiconque peut lire les Secrets via l'API les voit en clair. Pour ameliorer : encryption at rest cote API server, un vrai vault (ou Sealed Secrets / External Secrets), et limiter qui a le droit `get secrets` avec le RBAC.

## 5. Base + overlays

La base a le Deployment / Service commun. Chaque overlay change le namespace, le nombre de replicas et les labels. Meme appli, 3 cibles. En vrai hybrid/multi-cloud on changerait aussi le registry, le storage class, l'Ingress, etc. On-prem et cloud c'est surtout le reseau, les LB et le stockage qui changent, pas forcement les manifests de l'app.

## 6. Pourquoi le bad rollout n'a pas coupe l'app ?

Le tag `broken` n'existait pas. Les nouveaux pods sont restes en ErrImagePull. Les anciens pods Ready ont continue a repondre. Le rolling update ne coupe les vieux pods que quand les nouveaux sont ok.

## 7. Retrouver commit / reviewer / pipeline depuis un pod prod

On regarde l'image du pod + les annotations du Deployment (`git-commit`, `pipeline-run`, `owner`, `ticket`). Le SHA renvoie au commit GitHub, la PR montre qui a review, et le lien Actions montre le run qui a build/publish l'image.

## 8. Pourquoi kubectl edit en prod c'est risque

Parce que ca modifie le cluster sans passer par Git. Ensuite le repo et ce qui tourne ne matchent plus. Un prochain `kubectl apply` peut ecraser le changement a la main, et on perd la tracabilite (commit, review, CI). Mieux vaut passer par un overlay + PR.

## Preuves

Replicas :

```text
NAMESPACE   NAME    READY
dev         myapp   2/2
staging     myapp   3/3
prod        myapp   5/5
```

RBAC :

```text
kubectl auth can-i delete pods -n dev --as=system:serviceaccount:dev:viewer
no

kubectl auth can-i list pods -n dev --as=system:serviceaccount:dev:viewer
yes
```

Annotations prod :

```text
git-commit: c33ee82e96870c4d0a00ced3cdacd9e6fcb7957e
pipeline-run: https://github.com/Ruban-Adhesif/devops-project/actions
owner: team-a
ticket: OPS-123
```

Rolling update / rollback :

- image `v2`, `/health` = `OK v2`
- pendant le rollout, les curls sont restes en 200
- tag `broken` -> ErrImagePull, les pods v2 repondaient encore
- `kubectl rollout undo deployment/myapp -n dev` a remis la revision d'avant
