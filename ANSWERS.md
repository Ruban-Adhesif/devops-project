# Session 2 - reponses

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

---

# Session 3 - answers

## 1. What did Terraform propose after deleting the container by hand?

It wanted to create the container again (`docker_container.web will be created`, `1 to add`). The state still said the container exists, but in real life it was gone. This is called **drift**: the real infra doesn't match what Terraform thinks it has.

## 2. Why never commit the state file?

- It can have secrets in plain text (passwords, tokens, IPs...).
- If everyone pushes their own state, you get conflicts and people overwrite each other.
- Git has no locking, so two people can apply at the same time and break stuff.

Better to keep it in a remote backend.

## 3. One folder + one state per env vs workspaces

Each env has its own folder, its own tfvars and its own state, so it's easy to see what's going on. If you mess up dev, staging is not touched. With workspaces it's the same code and you just switch, so it's easy to forget which one you're on and apply on the wrong env. Folders also let envs be a bit different if needed.

## 4. Why a remote backend with locking for a team?

Everyone uses the same state, not a copy on their laptop. Locking means only one person can apply at a time. It prevents:

- two applies at once that corrupt the state
- someone working with an old state and deleting/recreating stuff
- losing the state if a laptop dies

In the lab we faked it with a shared folder (`.tf-backend/dev/`) and `terraform init -migrate-state`. It works, but a local folder has no real locking and nobody else can reach it, so in real life you'd use S3 + DynamoDB, GCS, Terraform Cloud, etc.

## 5. What can be sensitive in a state file?

Basically all the resource attributes, in clear: passwords, API keys, tokens, private keys, connection strings, IPs, internal names. Even if a variable is marked `sensitive`, the value is still in the state.

## 6. What if the preview env is never destroyed?

- It costs money / eats cluster resources for nothing
- Tons of old namespaces, hard to know what is still used
- Old images and configs still running = security risk

Mitigations:

1. Auto `terraform destroy` in CI when the PR is closed or merged
2. `expires` + `owner` labels and a cron job that deletes expired namespaces
3. Quotas (ResourceQuota) per namespace + a limit on how many previews can exist

## 7. Why plan on PR but apply only after merge?

The plan shows what will change so the reviewer can check it before. Apply changes real infra, so it should only happen on reviewed and merged code. Also if you applied on every PR, multiple PRs would fight over the same infra and main wouldn't match what's deployed.

## 8. Why short-lived creds (OIDC) and not long-lived keys?

Long keys sit in the CI secrets forever. If they leak, someone can use them until someone notices and rotates them. With OIDC the pipeline gets a token that lasts a few minutes and only for that repo/branch. Nothing to store, nothing to rotate, and if it leaks it's already expired.

## Proofs

Modules, 2 envs side by side:

```text
webapp-staging  0.0.0.0:8092->80/tcp
webapp-dev      0.0.0.0:8091->80/tcp
```

State list (dev, after moving to the shared backend):

```text
module.webapp.docker_container.web
module.webapp.docker_image.app
```

Drift: recreated `webapp-dev` by hand with Docker on port 8093, then:

```text
$ terraform plan -refresh-only -var-file=dev.tfvars
Note: Objects have changed outside of Terraform
  # module.webapp.docker_container.web has been deleted

$ terraform plan -var-file=dev.tfvars
          + external = 8091
Plan: 1 to add, 0 to change, 0 to destroy.
```

Terraform tracks the container by its ID, so the new one is "unknown" and it thinks the old one is gone. Had to `docker rm -f` the manual one (name conflict), then apply -> `No changes. Your infrastructure matches the configuration.`

Preview envs (one state per PR: `state/pr-42.tfstate`, `state/pr-43.tfstate`):

```text
$ kubectl get ns -l purpose=preview --show-labels
NAME    STATUS   LABELS
pr-42   Active   expires=2026-11-29,owner=team-a,pr=42,purpose=preview
pr-43   Active   expires=2026-11-29,owner=team-a,pr=43,purpose=preview

$ kubectl get pods -n pr-42
myapp-79cdd6854b-4n8vz   1/1   Running
$ kubectl get pods -n pr-43
myapp-79cdd6854b-xkn2g   1/1   Running

$ curl localhost:18042/health   (port-forward to pr-42)
OK v2
```

Destroy preview 42:

```text
$ terraform init -reconfigure -backend-config="path=state/pr-42.tfstate"
$ terraform destroy -var="pr_number=42" -var="image=myapp:c96f34d"
Destroy complete! Resources: 3 destroyed.

$ kubectl get ns -l purpose=preview
pr-43   Active        <- 43 still alive, 42 gone
$ kubectl get all -n pr-42
No resources found in pr-42 namespace.
```

Note: the ghcr image is only built for amd64 and my Mac is arm64, so I built it locally and did `kind load docker-image myapp:c96f34d`.

Terraform CI (`.github/workflows/terraform.yml`), on PRs touching `infra/**`:

- `validate`: fmt -check + init -backend=false + validate on every folder
- `plan`: plan for dev and staging, uploaded as artifacts `plan-dev` / `plan-staging`
- `security`: checkov on `infra/`
- no apply anywhere, token is read-only

We tried trivy first but it doesn't check `kubernetes_*` Terraform resources, so a bad k8s setting wasn't caught. Checkov does. Checkov free version has no severity levels (needs a paid API key), so instead of "fail on high" we fail on **any** failed check, which is stricter.

First checkov run found 6 problems in the preview. Fixed 3 for real (pod + container `securityContext`: non-root, no privilege escalation, read-only root fs, drop ALL caps). Skipped 3 with a reason in the code (image tag from a variable, SHA tag instead of digest, pull policy Always would break kind local images).

```text
clean:          Passed checks: 26, Failed checks: 0, Skipped checks: 3
privileged=true: Passed checks: 25, Failed checks: 1, Skipped checks: 3
                Check: CKV_K8S_16: "Do not admit privileged containers"
```
