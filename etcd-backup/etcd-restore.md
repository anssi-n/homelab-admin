Phase 0 – Preparation (before any outage)Identify the exact snapshot you want (newest healthy one):bash

aws s3 ls s3://YOUR-BUCKET/etcd/ --recursive | sort

Note the member names and peer URLs of your current cluster (they must match during restore):bash

# On a healthy control-plane node
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list -w table

Have the age private key ready on a secure machine.

Phase 1 – Download & Decrypt the snapshotOn a secure workstation (or one of the control-plane nodes if you accept the risk):bash

# Download
aws s3 cp s3://YOUR-BUCKET/etcd/etcd-YYYYMMDDTHHMMSSZ-NODE.db.zst.age .

# Decrypt (private key must be present)
age -d -i /path/to/etcd-backup-age.key -o etcd-snapshot.db.zst etcd-YYYYMMDDTHHMMSSZ-NODE.db.zst.age

# Decompress
zstd -d etcd-snapshot.db.zst
# → you now have etcd-snapshot.db ready for etcdutl snapshot restore

# Verify integrity
etcdutl snapshot status etcd-snapshot.db --write-out=table

Copy the decrypted etcd-snapshot.db to every control-plane node (e.g. /root/etcd-snapshot.db).Phase 2 – Stop the control plane (all nodes simultaneously)On every control-plane node:bash

# Move static pod manifests out of the way (kubelet will stop the pods)
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/
sudo mv /etc/kubernetes/manifests/etcd.yaml          /root/
# Optional but recommended
sudo mv /etc/kubernetes/manifests/kube-controller-manager.yaml /root/
sudo mv /etc/kubernetes/manifests/kube-scheduler.yaml          /root/

# Wait until the pods are gone
sudo crictl ps | grep -E 'etcd|kube-apiserver' || echo "stopped"

Phase 3 – Restore the snapshot (all members)Important: Use the same snapshot and the same --initial-cluster-token on every node.
Use a new data directory (never overwrite the live one while it is still mounted).Example for a 3-node cluster (adjust names/IPs to match your environment):bash

# ---------- On control-plane-1 (10.0.0.11) ----------
sudo etcdutl snapshot restore /root/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored \
  --name=control-plane-1 \
  --initial-cluster=control-plane-1=https://10.0.0.11:2380,control-plane-2=https://10.0.0.12:2380,control-plane-3=https://10.0.0.13:2380 \
  --initial-cluster-token=etcd-cluster-restored-$(date +%s) \
  --initial-advertise-peer-urls=https://10.0.0.11:2380 \
  --bump-revision=1000000000 \
  --mark-compacted

# ---------- On control-plane-2 (10.0.0.12) ----------
sudo etcdutl snapshot restore /root/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored \
  --name=control-plane-2 \
  --initial-cluster=control-plane-1=https://10.0.0.11:2380,control-plane-2=https://10.0.0.12:2380,control-plane-3=https://10.0.0.13:2380 \
  --initial-cluster-token=etcd-cluster-restored-<SAME-TOKEN-AS-ABOVE> \
  --initial-advertise-peer-urls=https://10.0.0.12:2380 \
  --bump-revision=1000000000 \
  --mark-compacted

# ---------- On control-plane-3 (10.0.0.13) ----------
# same pattern with its own name and peer URL

For a single control-plane node the command is simpler:bash

sudo etcdutl snapshot restore /root/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored \
  --name=control-plane-1 \
  --initial-cluster=control-plane-1=https://10.0.0.11:2380 \
  --initial-cluster-token=etcd-cluster-restored-$(date +%s) \
  --initial-advertise-peer-urls=https://10.0.0.11:2380 \
  --bump-revision=1000000000 \
  --mark-compacted

Phase 4 – Switch data directory & restartOn every control-plane node:bash

# Keep the old data just in case
sudo mv /var/lib/etcd /var/lib/etcd.old-$(date +%s)
sudo mv /var/lib/etcd-restored /var/lib/etcd
sudo chown -R root:root /var/lib/etcd   # or the user your etcd runs as

# Bring etcd back first
sudo mv /root/etcd.yaml /etc/kubernetes/manifests/

# Wait ~30–60 s, then bring the API server back
sudo mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/

# Optionally restore controller-manager & scheduler
sudo mv /root/kube-controller-manager.yaml /etc/kubernetes/manifests/
sudo mv /root/kube-scheduler.yaml          /etc/kubernetes/manifests/

Phase 5 – Verificationbash

# On any control-plane node
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

If everything looks healthy you can later remove the old data directories (/var/lib/etcd.old-*).Important notes & gotchasAlways restore into a new data directory.
Use --bump-revision and --mark-compacted for Kubernetes restores (prevents watch/cache problems).
The member names and peer URLs in --initial-cluster must match what the static pod manifests expect.
Certificates (/etc/kubernetes/pki) are not inside the etcd snapshot. Keep a separate backup of the PKI or be prepared to regenerate them with kubeadm.
After a restore the cluster identity changes (new cluster ID / member IDs). This is expected.
Test the whole procedure on a throw-away cluster at least once a year.

