# Argo Rollouts — Deployment Strategy Examples

## How Blue-Green works

```
                          ┌─────────────────────────────────────────────┐
                          │               Kubernetes Cluster             │
                          │                                              │
  Users ──► Ingress ──►  │  active-svc ──► [Blue  RS] v1 (3 pods)      │
                          │                                              │
  QA   ──► Ingress ──►   │  preview-svc ──► [Green RS] v2 (3 pods)     │
                          │                                              │
                          │  On promotion: active-svc selector flips    │
                          │  to Green RS; Blue RS scales down after 30s │
                          └─────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `namespace.yaml` | Creates the `demo` namespace |
| `services.yaml` | `active` (production) and `preview` (test) Services |
| `rollout.yaml` | Rollout resource with Blue-Green strategy + analysis hooks |
| `analysis-template.yaml` | Prometheus-based success-rate analysis |
| `ingress.yaml` | Routes `demo.example.com` → active, `preview.demo.example.com` → preview |
| `kustomization.yaml` | Kustomize entrypoint |

## Prerequisites

```bash
# Install Argo Rollouts controller
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin
brew install argoproj/tap/kubectl-argo-rollouts
```

## Deploy

```bash
kubectl apply -k blue-green/
```

## Workflow

### 1. Check initial state (Blue is active)
```bash
kubectl argo rollouts get rollout blue-green-demo -n demo --watch
```

### 2. Trigger an update (deploy Green)
```bash
kubectl argo rollouts set image blue-green-demo \
  app=argoproj/rollouts-demo:green -n demo
```

### 3. Test the preview (Green) before promoting
```bash
# Hit the preview service to validate
kubectl port-forward svc/blue-green-demo-preview 8081:80 -n demo
curl http://localhost:8081
```

### 4. Promote Green → make it the new Active
```bash
kubectl argo rollouts promote blue-green-demo -n demo
```

### 5. Abort / rollback to Blue
```bash
kubectl argo rollouts abort blue-green-demo -n demo
kubectl argo rollouts undo blue-green-demo -n demo
```

## Viewing on the UI

### Argo Rollouts Dashboard
```bash
# Launch the local dashboard (opens http://localhost:3100)
kubectl argo rollouts dashboard -n demo
```
Navigate to **http://localhost:3100** → select namespace `demo` → click **blue-green-demo**.

You will see:
- Active (Blue) and Preview (Green) ReplicaSets with pod counts
- Rollout phase and step status
- Promote / Abort buttons for manual control
- Live analysis run results

### Argo CD UI (if the app is managed by Argo CD)
```bash
# Port-forward the Argo CD server
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Open **https://localhost:8080** → find the app synced to this rollout.  
The resource tree shows the Rollout, active/preview Services, and ReplicaSets in real time.

## Key Rollout fields explained

| Field | Value | Meaning |
|-------|-------|---------|
| `autoPromotionEnabled` | `false` | Manual gate — you call `promote` |
| `scaleDownDelaySeconds` | `30` | Blue pods stay up 30s after promotion |
| `prePromotionAnalysis` | success-rate | Must pass before traffic switches |
| `postPromotionAnalysis` | success-rate | Runs after switch; aborts on failure |

---

# Argo Rollouts — Canary Deployment Demo

## How Canary works

```
                         ┌──────────────────────────────────────────────────┐
                         │               Kubernetes Cluster                  │
                         │                                                    │
  Users ──► Ingress ──► │  90% ──► stable-svc ──► [Stable RS] v1 (9 pods)  │
                         │  10% ──► canary-svc  ──► [Canary RS] v2 (1 pod)  │
                         │                                                    │
                         │  Weight increases step by step (10→30→60→100%).   │
                         │  Analysis gates block advancement on errors.       │
                         │  On 100%: stable RS replaced; canary RS removed.  │
                         └──────────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `namespace.yaml` | Creates the `demo` namespace |
| `services.yaml` | `stable` (current) and `canary` (new) Services |
| `rollout.yaml` | Rollout resource with Canary strategy + graduated steps |
| `analysis-template.yaml` | Prometheus success-rate + HTTP-check analysis |
| `ingress.yaml` | NGINX ingress — Argo Rollouts manages the canary weight annotations |
| `kustomization.yaml` | Kustomize entrypoint |

## Deploy

```bash
kubectl apply -k canary/
```

## Rollout steps (as configured)

| Step | Weight | Gate |
|------|--------|------|
| 1 | 10% | 2-minute automatic pause |
| 2 | 10% | Prometheus analysis (3× pass required) |
| 3 | 30% | Manual pause — `kubectl argo rollouts promote` |
| 4 | 60% | 5-minute automatic soak |
| 5 | 60% | Prometheus analysis again |
| 6 | 100% | Full promotion; stable RS replaced |

## Workflow

### 1. Watch the rollout
```bash
kubectl argo rollouts get rollout canary-demo -n demo --watch
```

### 2. Trigger an update (deploy canary version)
```bash
kubectl argo rollouts set image canary-demo \
  app=argoproj/rollouts-demo:yellow -n demo
```

### 3. Monitor step progression
```bash
# The rollout pauses automatically at step 3 (30%) for manual approval.
# Check current traffic weight:
kubectl argo rollouts get rollout canary-demo -n demo
```

### 4. Manually promote past the indefinite pause
```bash
kubectl argo rollouts promote canary-demo -n demo
```

### 5. Abort / rollback to stable
```bash
kubectl argo rollouts abort canary-demo -n demo
kubectl argo rollouts undo canary-demo -n demo
```

## Viewing on the UI

### Argo Rollouts Dashboard
```bash
# Launch the local dashboard (opens http://localhost:3100)
kubectl argo rollouts dashboard -n demo
```
Navigate to **http://localhost:3100** → select namespace `demo` → click **canary-demo**.

You will see:
- Stable and Canary ReplicaSets with current pod counts
- Current step number and traffic weight (e.g. 10% → 30% → 60%)
- Active AnalysisRun status and metric results
- Promote / Abort buttons for manual gate control

### Argo CD UI (if the app is managed by Argo CD)
```bash
# Port-forward the Argo CD server
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Open **https://localhost:8080** → find the app synced to this rollout.  
The resource tree shows the Rollout, stable/canary Services, Ingress weight annotations, and AnalysisRuns updating live.

## Key Rollout fields explained (Canary)

| Field | Value | Meaning |
|-------|-------|---------|
| `stableService` | canary-demo-stable | Always points at the stable (old) ReplicaSet |
| `canaryService` | canary-demo-canary | Points only at the new canary pods |
| `trafficRouting.nginx` | stableIngress | Uses NGINX weight annotations for true traffic splitting |
| `steps[].setWeight` | 10/30/60/100 | Percentage of traffic sent to canary |
| `steps[].pause: {}` | — | Indefinite hold — requires manual `promote` to continue |
| `steps[].pause.duration` | 2m / 5m | Automatic hold for a fixed time before advancing |
| `steps[].analysis` | canary-success-rate | AnalysisRun gate — fails the rollout on error budget breach |
| `scaleDownDelaySeconds` | 30 | Old stable RS stays alive 30s after full promotion |
