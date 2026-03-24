**요약:**
빌드된 라이브러리(JAR, WAR)와 아티팩트를 관리하는 **Nexus Repository Manager** 구축 가이드입니다. Nexus는 개발팀의 공용 창고 역할을 하며, 외부 라이브러리를 캐싱하여 빌드 속도를 높여줍니다. 운영 표준인 **Ingress-Nginx**를 통해 포트 번호 없이 접속하도록 설정하며, 자바 기반 도구 특유의 **메모리 최적화** 설정을 포함했습니다.

---

# 📦 Stage 15: Maven Repository - Nexus Repository Manager 구축 가이드

## 1. 개요

* **역할:** 자바 프로젝트의 결과물(JAR)을 저장하거나, Maven/Gradle 빌드 시 필요한 외부 라이브러리를 중앙에서 관리(Proxy)합니다.
* **특징:** Maven뿐만 아니라 Docker, Helm, NPM, PyPI 등 다양한 포맷의 저장소를 한곳에서 운영할 수 있습니다.

---

## 2. Helm 설정 파일 생성 (`nexus-values.yaml`)

Nexus는 실행 시 상당한 메모리를 소모하므로, 클라우드 VM 사양을 고려하여 JVM 옵션을 조정해야 합니다.

```yaml
# nexus-values.yaml
statefulset:
  enabled: true

# [🔥핵심] 메모리 최적화 설정 (DS2_v2 사양 고려)
nexus:
  env:
    - name: INSTALL4J_ADD_VM_PARAMS
      value: "-Xms1200M -Xmx1200M -XX:MaxDirectMemorySize=1G"
  resources:
    requests:
      cpu: "500m"
      memory: "2Gi"
    limits:
      cpu: "1000m"
      memory: "2Gi"

# 데이터 보존을 위한 스토리지 설정
persistence:
  enabled: true
  accessMode: ReadWriteOnce
  size: 20Gi

# 운영 표준 인그레스 설정
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0" # 대용량 파일 업로드 허용
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
  hostPath: /
  hostRepo: nexus.20.196.204.108.nip.io # [본인의 공인IP로 수정]

```

---

## 3. Nexus 설치 (Helm 실행)

공식 차트인 `sonatype/nexus-repository-manager`를 사용합니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add sonatype https://sonatype.github.io/helm3-charts/
helm repo update

# 2. 설치 (네임스페이스: nexus)
helm install nexus sonatype/nexus-repository-manager \
  --namespace nexus --create-namespace \
  -f nexus-values.yaml

```

---

## 4. 최종 접속 및 초기 비밀번호 확인

1. **접속 주소:** `http://nexus.20.196.204.108.nip.io`
2. **초기 비밀번호 확인 (admin 계정):**
Nexus는 최초 접속 시 서버 내부 파일에 임시 비밀번호를 생성합니다.
```bash
# 파드 내부에 저장된 초기 비밀번호 확인
kubectl exec -it <nexus-pod-name> -n nexus -- cat /nexus-data/admin.password

```


3. **로그인:** 아이디 `admin`과 위에서 확인한 비밀번호로 로그인 후, 안내에 따라 즉시 비밀번호를 변경하세요.

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "메모리 부족으로 인한 무한 재시작"

* **증상:** 파드가 `Running`이 된 후 얼마 지나지 않아 `CrashLoopBackOff`에 빠짐.
* **원인:** Nexus(Java)는 설정된 Heap 메모리 외에도 직접 메모리(Direct Memory)를 많이 사용합니다. VM 메모리가 7~8GB인 환경에서 다른 도구(ELK, SonarQube)와 함께 돌리면 메모리 경합이 발생합니다.
* **해결:** `INSTALL4J_ADD_VM_PARAMS` 설정을 통해 힙 메모리를 타이트하게 잡고, 불필요한 다른 파드를 잠시 종료하세요.

### 📍 삽질 2: "Artifact 업로드 중 413 에러"

* **상황:** 용량이 큰 JAR 파일이나 이미지를 업로드할 때 `413 Request Entity Too Large` 발생.
* **원인:** Ingress-Nginx의 기본 파일 업로드 제한(1MB) 때문입니다.
* **해결:** 인그레스 설정(`annotations`)에 `proxy-body-size: "0"` (무제한)을 반드시 추가해야 합니다.

### 📍 삽질 3: "데이터 증발 현상"

* **상황:** 파드를 재시작했더니 설정한 저장소와 업로드한 파일이 모두 사라짐.
* **해결:** `persistence.enabled: true` 설정이 정상적으로 적용되었는지, 그리고 `kubectl get pvc -n nexus`가 `Bound` 상태인지 확인하세요. (NFS Provisioner 필수)

---