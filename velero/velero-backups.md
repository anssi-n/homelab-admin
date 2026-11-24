## Prerequisites

```
kubectl label volumesnapshotclass longhorn-snapshot velero.io/csi-volumesnapshot-class=true
```

## Jenkins

```
velero schedule create jenkins-weekly \
  --schedule "0 18 * * 0" \
  --include-namespaces jenkins \
  --include-cluster-resources=true \
  --snapshot-move-data \
  --parallel-files-upload=8 \
  --ttl 720h0m0s
```

## HuutoApp

Create configmap for volume policy. Policy skips database and redis volumes.
```
kubectl -n velero create configmap huutoapp-volume-policy \
  --from-file=policy.yaml=huutoapp-volume-policy.yaml
```

```
velero schedule create huutoapp-weekly \
  --schedule "0 17 * * 0" \
  --include-namespaces huutoapp \
  --include-cluster-resources=true \
  --snapshot-move-data \
  --resource-policies-configmap huutoapp-volume-policy \
  --ttl 720h0m0s
```

# Harbor

Create configmap for volume policy. Policy skips container image and trivy volumes.

```
kubectl -n velero create configmap harbor-volume-policy \
  --from-file=policy.yaml=harbor-volume-policy.yaml
```

```
velero schedule create harbor-weekly \
  --schedule "0 18 * * 0" \
  --include-namespaces harbor \
  --include-cluster-resources=true \
  --snapshot-move-data \
  --resource-policies-configmap harbor-volume-policy \
  --ttl 720h0m0s
``````

