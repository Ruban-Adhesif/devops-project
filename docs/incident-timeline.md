# Incident timeline (UTC)

Session 5, 24 novembre 2026. Faute injectee : image `bad-error-rate` (HTTP 500 sur `/`, `/slow` et `/error`, `/health` et `/metrics` restent en 200).

Roles :
- Incident commander : Ruben
- Technical lead : Kais
- Communications et scribe : Sami

| Time | Event | Author |
|------|-------|--------|
| 13:22:31 | Image `ghcr.io/ruban-adhesif/devops-project:bad-error-rate` deployee sur `deployment/myapp` dans `dev` | saboteur |
| 13:22:43 | Rollout termine. Les 2 pods sont Running et Ready : la probe `/health` repond 200 | saboteur |
| 13:22:46 | Trafic vers `/` et `/error` | saboteur |
| 13:24:21 | Alerte `HighErrorRate` en FIRING, ratio de 5xx ≈ 99,9 % | Prometheus |
| 13:24:37 | Diagnostic : pods Ready, image `bad-error-rate`, logs JSON `level=error` `status=500` sur `/` et `/error`. Loki : `{app="myapp"} \| json \| level="error"` | Ruben |
| 13:24:59 | Mitigation : `kubectl rollout undo deployment/myapp -n dev` | Ruben |
| 13:25:11 | Pods revenus sur `ghcr.io/ruban-adhesif/devops-project:2cb63a64f11ad52196cb8f6aec891baf943199c1`, trafic arrete | Ruben |
| 13:27:45 | Ratio de 5xx a 0, alerte `inactive`. All-clear | Prometheus |

Delais :
- Detection : 13:24:21 − 13:22:31 = 1 min 50 s
- Mitigation depuis la detection : 13:24:59 − 13:24:21 = 38 s
- Duree totale jusqu'a l'all-clear : 13:27:45 − 13:22:31 = 5 min 14 s
- Impact utilisateur (pods casses jusqu'au rollback) : 13:22:43 − 13:25:11 = 2 min 28 s
