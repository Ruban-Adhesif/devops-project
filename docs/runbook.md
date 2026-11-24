# Runbook - HighErrorRate

## Symptomes

- L'alerte `HighErrorRate` (severity `critical`) est en FIRING.
- Le ratio de reponses 5xx de `myapp` est au-dessus de 10 % depuis plus de 2 minutes.

## Checks rapides

1. Les pods tournent ? Restarts, CrashLoopBackOff, pods pas Ready :

   ```bash
   kubectl get pods -n dev
   ```

2. Ce que l'app logge (logs JSON, chercher les `status` 5xx et les erreurs) :

   ```bash
   kubectl logs deployment/myapp -n dev --tail=50
   ```

3. Le ratio actuel dans Prometheus / Grafana :

   ```promql
   sum(rate(http_requests_total{status=~"5.."}[2m])) / sum(rate(http_requests_total[2m]))
   ```

4. Un deploiement recent ? (`kubectl rollout history deployment/myapp -n dev`)

## Mitigation

Rollback d'abord, on cherche la cause apres :

```bash
kubectl rollout undo deployment/myapp -n dev
kubectl rollout status deployment/myapp -n dev
```

Puis verifier que le ratio redescend sous 10 % et que l'alerte repasse en resolved.

## Apres l'incident

- Garder la timeline (heure de l'alerte, du rollback, du retour a la normale).
- Ecrire le postmortem dans `docs/postmortem.md`, sans blame.
