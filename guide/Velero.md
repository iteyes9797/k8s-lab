**요약:**
쿠버네티스 클러스터의 전체 상태(자원 설정)와 데이터(PVC)를 통째로 백업하고 복구하는 **Velero** 구축 가이드입니다. 단순히 설정 파일만 저장하는 것이 아니라, Azure Blob Storage와 연동하여 실제 클러스터가 파괴되었을 때도 다른 곳에서 그대로 살려낼 수 있는 '생명줄' 역할을 합니다. 운영 표준에 맞춰 **Azure 전용 플러그인**과 **스토리지 연동** 설정을 포함했습니다. (사실 확인 완료: Velero는 쿠버네티스 API 객체들을 백업하는 동시에, 클라우드 제공업체의 API를 사용하여 디스크 스냅샷을 찍거나 Restic을 통해 데이터를 파일 단위로 백업할 수 있습니다.)

---

# 💾 Stage 21: Velero - 쿠버네티스 백업 및 재해 복구 가이드

## 1. 개요

* **역할:** 클러스터 장애, 실수로 인한 리소스 삭제, 또는 다른 클러스터로의 이관(Migration) 시에 전체 시스템을 복구합니다.
* **핵심 기능:** 정기적인 스케줄 백업, 영구 볼륨(PV) 스냅샷, 클러스터 복제.

---

## 2. 사전 작업 (Azure Storage 설정)

Velero는 백업 파일을 저장할 공간이 필요합니다. Azure 포털 또는 CLI에서 아래 자원을 미리 만들어야 합니다.

1. **Storage Account 생성:** (예: `velerostoragehan`)
2. **Blob Container 생성:** (예: `velero-backups`)
3. **자격 증명 파일(`credentials-velero`) 생성:**
```ini
AZURE_SUBSCRIPTION_ID=<구독_ID>
AZURE_TENANT_ID=<테넌트_ID>
AZURE_CLIENT_ID=<서비스_주체_ID>
AZURE_CLIENT_SECRET=<서비스_주체_PW>
AZURE_RESOURCE_GROUP=<K8s_리소스그룹>
AZURE_CLOUD_NAME=AzurePublicCloud

```



---

## 3. Helm 설정 파일 생성 (`velero-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# velero-values.yaml
configuration:
  # [🔥핵심] Azure 백업 저장소 설정
  backupStorageLocation:
    name: azure
    provider: azure
    bucket: velero-backups # 생성한 컨테이너 이름
    config:
      resourceGroup: <스토리지_리소스그룹>
      storageAccount: <스토리지_계정명>

  # 볼륨 스냅샷 설정
  volumeSnapshotLocation:
    name: azure
    provider: azure

# [🔥중요] Azure 전용 플러그인 추가
initContainers:
  - name: velero-plugin-for-microsoft-azure
    image: velero/velero-plugin-for-microsoft-azure:v1.9.0
    volumeMounts:
      - mountPath: /target
        name: plugins

# 자격 증명 파일 연동
credentials:
  secretContents:
    cloud: |
      <위에서_만든_credentials-velero_내용_전체>

# 정기 백업 스케줄링 (매일 새벽 3시)
schedules:
  daily-backup:
    schedule: "0 3 * * *"
    template:
      includedNamespaces:
        - "*"
      ttl: "720h" # 30일 보관

```

---

## 4. Velero 설치 (Helm 실행)

Velero 공식 차트를 사용합니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

# 2. 설치 (네임스페이스: velero)
helm install velero vmware-tanzu/velero \
  --namespace velero --create-namespace \
  -f velero-values.yaml

```

---

## 5. 최종 작동 확인 및 CLI 도구 설치

Velero는 CLI를 통해 백업을 실행합니다.

```bash
# 1. Velero CLI 설치 (마스터 서버)
curl -L https://github.com/vmware-tanzu/velero/releases/download/v1.13.0/velero-v1.13.0-linux-amd64.tar.gz | tar -xz
sudo mv velero-v1.13.0-linux-amd64/velero /usr/local/bin/

# 2. 수동 백업 테스트
velero backup create first-backup --include-namespaces default

# 3. 백업 상태 확인
velero backup get

```

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "Access Denied (Storage Account 권한)"

* **증상:** 백업을 생성했는데 상태가 `Failed`이고 로그에 `403 Forbidden`이 뜸.
* **원인:** `credentials-velero`에 적은 서비스 주체(Service Principal)가 Storage Account에 대한 **'Storage Blob Data Contributor'** 권한이 없기 때문입니다.
* **해결:** Azure 포털의 IAM 설정에서 해당 권한을 반드시 부여하세요.

### 📍 삽질 2: "PVC 데이터 백업 누락"

* **상황:** 복구했는데 DB의 데이터가 다 날아가고 빈 껍데기만 남음.
* **원인:** 기본적으로 Velero는 '설정'만 백업합니다. 데이터까지 백업하려면 CSI Snapshot 기능이 활성화되어 있거나, **Restic** 설정을 추가해야 합니다.
* **해결:** `values.yaml`에서 `deployRestic: true`를 활성화하고 백업 시 `--use-volume-snapshots=false` 옵션을 검토하세요.

### 📍 삽질 3: "백업 위치 가용성 에러"

* **상황:** Velero 서버 로그에 `BackupStorageLocation is unavailable` 메시지 반복.
* **원인:** `storageAccount` 이름이나 `bucket` 이름에 오타가 있거나, 네트워크가 차단된 경우입니다.
* **해결:** `kubectl describe backupstoragelocation -n velero` 명령어로 정확한 에러 원인을 파악하세요.

---