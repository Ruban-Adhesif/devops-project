# Session 2 answers

## Question 1

A namespace separates resources in the same cluster: `dev`, `staging` and `prod` can each have a Service named `myapp` without colliding. It does not give strong security isolation by itself. By default a pod in one namespace can still talk to another if the network policy allows it. Isolation comes from NetworkPolicy, RBAC and maybe separate clusters.

## Question 2

We asked for 3 replicas on the Deployment. When one pod is deleted, the ReplicaSet controller notices that Current is below Desired and creates a new pod. The Deployment owns the ReplicaSet, the ReplicaSet recreates the pods.

## Question 3

Readiness decides if the pod receives traffic. If it fails, the Endpoints remove the pod, the Service stops sending requests there, but the pod keeps running. Liveness decides if the container is still healthy. If it fails, kubelet restarts the container. In the lab, pointing both probes to `/nope` made Ready go to False and showed Unhealthy events.

## Question 4

A Kubernetes Secret is only base64 encoded in etcd by default, not encrypted in a useful way. Anyone with API access to Secrets can read them. Better options: enable encryption at rest on the API server, store real secrets in a vault (Sealed Secrets, External Secrets, cloud KMS), and keep RBAC tight so few accounts can get Secrets.

## Question 5

Base holds what is common. Each overlay changes namespace, replicas and labels for one target. Same app description, three environments. In a real hybrid setup, overlays can also change the image registry, storage class, Ingress class or node selectors. On-prem and cloud clusters differ on networking, load balancers, storage and how you authenticate to the registry. The app manifests stay close.

## Question 6

The broken image tag never became Ready. The new pods stayed on ErrImagePull / ImagePullBackOff. The old Ready pods kept answering. The Deployment did a rolling update, so it only replaces pods when the new ones are healthy. Traffic stayed on the working ReplicaSet.

## Question 7

From a prod pod, read the image tag and the Deployment annotations (`git-commit`, `pipeline-run`, `owner`, `ticket`). The commit SHA points to GitHub, where the Pull Request shows the reviewer. The pipeline-run URL points to the Actions run that built and published the image.

## Question 8

`kubectl edit` in production changes the live object without going through Git. The next `kubectl apply` from the repo can overwrite or conflict with that change. The commit, the PR and the pipeline no longer match what is running. Changes should go through the overlays, a PR and the CI.

## Evidence

### Replicas per environment

```text
NAMESPACE   NAME    READY
dev         myapp   2/2
staging     myapp   3/3
prod        myapp   5/5
```

### RBAC checks

```text
kubectl auth can-i delete pods -n dev --as=system:serviceaccount:dev:viewer
no

kubectl auth can-i list pods -n dev --as=system:serviceaccount:dev:viewer
yes
```

### Prod annotations

```text
git-commit: c33ee82e96870c4d0a00ced3cdacd9e6fcb7957e
pipeline-run: https://github.com/Ruban-Adhesif/devops-project/actions
owner: team-a
ticket: OPS-123
```

### Rolling update and rollback

- Image updated to `v2`, `/health` answered `OK v2`.
- During the rollout, repeated curls stayed on HTTP 200.
- Tag `broken` put a new pod in `ErrImagePull` while the old pods still answered `OK v2`.
- `kubectl rollout undo deployment/myapp -n dev` restored the previous revision.
