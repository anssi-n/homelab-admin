# Phase 0 – Preparation (before any outage)

## Identify the exact snapshot you want (newest healthy one)

```
aws s3 ls s3://YOUR-BUCKET/etcd/ --recursive | sort
```

## On a healthy control-plane node

Note the member names and peer URLs of your current cluster (they must match during restore)

```
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list -w table
```
For example:

```
+------------------+---------+-----------------+----------------------------+----------------------------+------------+
|        ID        | STATUS  |      NAME       |         PEER ADDRS         |        CLIENT ADDRS        | IS LEARNER |
+------------------+---------+-----------------+----------------------------+----------------------------+------------+
| bd5a1e9e48e15a72 | started | control-plane-1 | https://192.168.1.147:2380 | https://192.168.1.147:2379 |      false |
+------------------+---------+-----------------+----------------------------+----------------------------+------------+
```

Have the age private key ready on a secure machine.

# Phase 1 – Download & Decrypt the snapshot

## Download
```
aws s3 cp s3://YOUR-BUCKET/etcd/etcd-YYYYMMDDTHHMMSSZ-NODE.db.zst.age .
```
## Decrypt (private key must be present)
```
age -d -i /path/to/etcd-backup-age.key -o etcd-snapshot.db.zst etcd-YYYYMMDDTHHMMSSZ-NODE.db.zst.age
```

## Decompress
```
zstd -d etcd-snapshot.db.zst
```
You now have etcd-snapshot.db ready for etcdutl snapshot restore.

## Verify integrity
```
etcdutl snapshot status etcd-snapshot.db --write-out=table
```
Copy the decrypted etcd-snapshot.db to every control-plane node (e.g. /root/etcd-snapshot.db).

# Phase 2 – Stop the control plane

Execute tasks on every control-plane node simultaneously.

## Move static pod manifests out of the way (kubelet will stop the pods)
```
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/
sudo mv /etc/kubernetes/manifests/etcd.yaml          /root/
```
## Optional but recommended
```
sudo mv /etc/kubernetes/manifests/kube-controller-manager.yaml /root/
sudo mv /etc/kubernetes/manifests/kube-scheduler.yaml          /root/
```

## Wait until the pods are gone
```
sudo crictl ps | grep -E 'etcd|kube-apiserver' || echo "stopped"
```

# Phase 3 – Restore the snapshot

Important: Use the same snapshot and the same --initial-cluster-token on every node.
Use a new data directory (never overwrite the live one while it is still mounted).

## Example for a 3-node cluster (adjust names/IPs to match your environment):
- control-plane-1, 10.0.0.11
- control-plane-2, 10.0.0.12
- control-plane-3, 10.0.0.13

### control-plane-1 (10.0.0.11)
```
sudo etcdutl snapshot restore /root/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored \
  --name=control-plane-1 \
  --initial-cluster=control-plane-1=https://10.0.0.11:2380,control-plane-2=https://10.0.0.12:2380,control-plane-3=https://10.0.0.13:2380 \
  --initial-cluster-token=etcd-cluster-restored-$(date +%s) \
  --initial-advertise-peer-urls=https://10.0.0.11:2380 \
  --bump-revision=1000000000 \
  --mark-compacted
```

### control-plane-2 (10.0.0.12)
```
sudo etcdutl snapshot restore /root/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored \
  --name=control-plane-2 \
  --initial-cluster=control-plane-1=https://10.0.0.11:2380,control-plane-2=https://10.0.0.12:2380,control-plane-3=https://10.0.0.13:2380 \
  --initial-cluster-token=etcd-cluster-restored-<SAME-TOKEN-AS-ABOVE> \
  --initial-advertise-peer-urls=https://10.0.0.12:2380 \
  --bump-revision=1000000000 \
  --mark-compacted
```

### control-plane-3 (10.0.0.13) 
```
sudo etcdutl snapshot restore /root/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored \
  --name=control-plane-2 \
  --initial-cluster=control-plane-1=https://10.0.0.11:2380,control-plane-2=https://10.0.0.12:2380,control-plane-3=https://10.0.0.13:2380 \
  --initial-cluster-token=etcd-cluster-restored-<SAME-TOKEN-AS-ABOVE> \
  --initial-advertise-peer-urls=https://10.0.0.13:2380 \
  --bump-revision=1000000000 \
  --mark-compacted
```

## For a single control-plane node
```
sudo etcdutl snapshot restore /root/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored \
  --name=control-plane-1 \
  --initial-cluster=control-plane-1=https://10.0.0.11:2380 \
  --initial-cluster-token=etcd-cluster-restored-$(date +%s) \
  --initial-advertise-peer-urls=https://10.0.0.11:2380 \
  --bump-revision=1000000000 \
  --mark-compacted
```

# Phase 4 – Switch data directory & restart

Execute tasks on every control-plane node.

## Keep the old data just in case
```
sudo mv /var/lib/etcd /var/lib/etcd.old-$(date +%s)
sudo mv /var/lib/etcd-restored /var/lib/etcd
sudo chown -R root:root /var/lib/etcd   # or the user your etcd runs as
```

## Bring etcd back first
```
sudo mv /root/etcd.yaml /etc/kubernetes/manifests/
```

## Wait ~30–60 s, then bring the API server back
```
sudo mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/
```

## Optionally restore controller-manager & scheduler
```
sudo mv /root/kube-controller-manager.yaml /etc/kubernetes/manifests/
sudo mv /root/kube-scheduler.yaml          /etc/kubernetes/manifests/
```

# Phase 5 – Verification

## On any control-plane node
```
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health --cluster

etcdctl member list -w table
etcdctl endpoint status -w table

kubectl get nodes
kubectl get pods -A
kubectl get --raw='/readyz?verbose'
```

If everything looks healthy you can later remove the old data directories (/var/lib/etcd.old-*).

# Important notes & gotchas

- Always restore into a new data directory.
- Use --bump-revision and --mark-compacted for Kubernetes restores (prevents watch/cache problems).
- The member names and peer URLs in --initial-cluster must match what the static pod manifests expect.
- Certificates (/etc/kubernetes/pki) are not inside the etcd snapshot. Keep a separate backup of the PKI or be prepared to regenerate them with kubeadm.
- After a restore the cluster identity changes (new cluster ID / member IDs). This is expected.

# Example how to restore /etc/kubernetes backups

Run this script on every control-plane node that needs the certificates.

```
#!/usr/bin/env bash
set -euo pipefail

# ---------- Configuration ----------
S3_BUCKET="s3://YOUR-BUCKET-NAME/etcd"
BACKUP_FILE="kubernetes-20261112T180000Z-control-plane-1.tar.gz.age"   # ← change to the file you want
AGE_KEY="/path/to/etcd-backup-age.key"                                 # private key
RESTORE_DIR="/root/k8s-restore-$$"
# ----------------------------------

echo "=== 1. Download encrypted backup ==="
mkdir -p "${RESTORE_DIR}"
cd "${RESTORE_DIR}"
aws s3 cp "${S3_BUCKET}/${BACKUP_FILE}" .

echo "=== 2. Decrypt ==="
age -d -i "${AGE_KEY}" -o kubernetes.tar.gz "${BACKUP_FILE}"

echo "=== 3. Extract ==="
tar -xzf kubernetes.tar.gz
# This creates ./etc/kubernetes/...

echo "=== 4. Safety backup of current /etc/kubernetes ==="
if [ -d /etc/kubernetes ]; then
  SAFETY_BACKUP="/etc/kubernetes.backup-$(date +%Y%m%dT%H%M%S)"
  echo "Creating safety backup at ${SAFETY_BACKUP}"
  cp -a /etc/kubernetes "${SAFETY_BACKUP}"
fi

echo "=== 5. Stop static pods (recommended) ==="
# Move manifests away so kubelet stops the control-plane pods
mkdir -p /root/manifests-backup
mv /etc/kubernetes/manifests/kube-apiserver.yaml          /root/manifests-backup/ 2>/dev/null || true
mv /etc/kubernetes/manifests/etcd.yaml                    /root/manifests-backup/ 2>/dev/null || true
mv /etc/kubernetes/manifests/kube-controller-manager.yaml /root/manifests-backup/ 2>/dev/null || true
mv /etc/kubernetes/manifests/kube-scheduler.yaml          /root/manifests-backup/ 2>/dev/null || true

echo "Waiting for static pods to stop..."
sleep 15

echo "=== 6. Restore /etc/kubernetes ==="
# Remove the old directory and put the restored one in place
rm -rf /etc/kubernetes
mv etc/kubernetes /etc/kubernetes

echo "=== 7. Fix permissions (important) ==="
chown -R root:root /etc/kubernetes
# Private keys should be readable only by root
find /etc/kubernetes -type f -name "*.key" -exec chmod 600 {} \;
find /etc/kubernetes -type f -name "*.crt" -exec chmod 644 {} \;
find /etc/kubernetes -type f -name "*.conf" -exec chmod 600 {} \;
chmod 700 /etc/kubernetes/pki 2>/dev/null || true
chmod 700 /etc/kubernetes/pki/etcd 2>/dev/null || true

echo "=== 8. Restore static pod manifests ==="
# Put the manifests back so kubelet starts the control-plane components again
mv /root/manifests-backup/* /etc/kubernetes/manifests/ 2>/dev/null || true

echo "=== 9. Cleanup ==="
cd /
rm -rf "${RESTORE_DIR}"

echo
echo "=== Restore of /etc/kubernetes completed ==="
echo "Check that control-plane pods are coming back:"
echo "  crictl ps | grep -E 'etcd|kube-apiserver|controller|scheduler'"
echo "  kubectl get nodes"
```

Recommended order when doing a full restore.

1. Stop control-plane static pods (as shown above).
2. Restore /etc/kubernetes (this script).
3. Restore the etcd snapshot (into a new data directory).
4. Start etcd first, then the API server and the rest of the control plane.
5. Verify cluster health.