# Restore Jenkins from Longhorn backup

```
Namespace: jenkins
PVC name: jenkins
Longhorn volume: pvc-d02adc3e-b1c4-4436-b528-590378017e44
StorageClass: longhorn-no-replicas
Size: 10Gi
```

## 1. Prepare – Scale Jenkins down & delete old PVC

### Scale Jenkins controller down

```
kubectl -n jenkins scale statefulset jenkins --replicas=0
```

### Wait until the pod is gone

```
kubectl -n jenkins get pods -w
```

### Delete the current PVC

```
kubectl -n jenkins delete pvc jenkins
```

## 2. Find the backup you want to restore

### List all backups for this volume

```
kubectl -n longhorn-system get backups.longhorn.io \
  -l backup-volume=pvc-d02adc3e-b1c4-4436-b528-590378017e44
NAME                      SNAPSHOTNAME            SNAPSHOTSIZE   SNAPSHOTCREATEDAT      BACKUPTARGET   STATE       LASTSYNCEDAT
backup-721034c8278c4ecb   snap-b450aca3db644216   3703570432     2026-11-24T12:51:42Z   default        Completed   2026-11-24T13:05:13Z
```

### Get the exact backup URL and size:

```
BACKUP_NAME=backup-721034c8278c4ecb

kubectl -n longhorn-system get backup $BACKUP_NAME \
  -o jsonpath='Backup URL: {.status.url}{"\n"}Size (bytes): {.status.volumeSize}{"\n"}'
Backup URL: s3://longhorn-backup-662914b058cf817b@eu-north-1/longhorn/?backup=backup-721034c8278c4ecb&volume=pvc-d02adc3e-b1c4-4436-b528-590378017e44
Size (bytes): 10737418240
```

## 3. Restore the volume

### Option A – Longhorn UI

- Longhorn UI → Backup
- Find volume pvc-d02adc3e-b1c4-4436-b528-590378017e44
- Select the desired backup → Restore
- Choose Use previous name
- Wait until the volume is Detached and healthy

### Option B – kubectl (declarative)

```
BACKUP_URL="s3://longhorn-backup-662914b058cf817b@eu-north-1/longhorn/?backup=backup-721034c8278c4ecb&volume=pvc-d02adc3e-b1c4-4436-b528-590378017e44"
VOLUME_SIZE="10737418240"   
```

```
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  name: pvc-d02adc3e-b1c4-4436-b528-590378017e44
  namespace: longhorn-system
spec:
  size: "10737418240"
  fromBackup: "s3://longhorn-backup-662914b058cf817b@eu-north-1/longhorn/?backup=backup-721034c8278c4ecb&volume=pvc-d02adc3e-b1c4-4436-b528-590378017e44"
  numberOfReplicas: 1
  frontend: blockdev
  dataEngine: v1
```

## 4. Create PV + PVC that bind to the restored volume

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pvc-d02adc3e-b1c4-4436-b528-590378017e44
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: longhorn-no-replicas
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeHandle: pvc-d02adc3e-b1c4-4436-b528-590378017e44
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins
  namespace: jenkins
  labels:
    recurring-job.longhorn.io/source: enabled
    recurring-job.longhorn.io/jenkins-backup: enabled
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: longhorn-no-replicas
  volumeName: pvc-d02adc3e-b1c4-4436-b528-590378017e44
```

## 5. Bring Jenkins back up

```
kubectl -n jenkins scale statefulset jenkins --replicas=1
```

### Check PVC is bound

```
kubectl -n jenkins get pvc jenkins
```

### Check volume is healthy

```
kubectl -n longhorn-system get volume pvc-d02adc3e-b1c4-4436-b528-590378017e44
```