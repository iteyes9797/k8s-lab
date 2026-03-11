**요약:**
코드의 품질과 보안 취약점을 분석하는 **SonarQube** 구축 가이드입니다. 소나큐브는 내부에 검색 엔진(Elasticsearch)을 포함하고 있어 **커널 파라미터 수정**이 필수이며, 데이터 저장을 위한 **PostgreSQL 데이터베이스**와 함께 배포됩니다. 운영 표준인 **Ingress-Nginx**를 통해 포트 번호 없이 접속하도록 설정했습니다.

---

# 🔍 Stage 10: SonarQube - 정적 코드 분석 도구 구축 가이드

## 1. 사전 작업 (호스트 커널 설정)

소나큐브 내부의 Elasticsearch가 정상 작동하려면 **모든 노드**에서 아래 설정을 확인해야 합니다. (Stage 8에서 이미 하셨다면 건너뛰셔도 됩니다.)

```bash
# 모든 노드 터미널에서 실행
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

```

---

## 2. Helm 설정 파일 생성 (`sonarqube-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# sonarqube-values.yaml
# 실습 환경(DS2_v2) 메모리 제한을 고려한 설정
resources:
  requests:
    cpu: "500m"
    memory: "2Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

# 내부 데이터베이스(PostgreSQL) 설정
postgresql:
  enabled: true
  persistence:
    enabled: true
    size: 10Gi

# 운영 표준 인그레스 설정
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    # 소나큐브는 분석 리포트 용량이 클 수 있어 업로드 제한을 늘려줍니다.
    nginx.ingress.kubernetes.io/proxy-body-size: "64m"
  hosts:
    - name: sonarqube.20.196.204.108.nip.io # [🔥본인의 공인IP로 수정]
      path: /

```

---

## 3. SonarQube 설치 (Helm 실행)

마스터 서버 터미널에서 실행합니다.

```bash
# 1. 레포지토리 추가
helm repo add sonarqube https://SonarSource.github.io/helm-charts-sonarqube
helm repo update

# 2. 설치 (네임스페이스: sonarqube)
helm install sonarqube sonarqube/sonarqube \
  --namespace sonarqube --create-namespace \
  -f sonarqube-values.yaml

```

---

## 4. 최종 접속 및 초기 비밀번호

1. **접속 주소:** `http://sonarqube.20.196.204.108.nip.io`
2. **로그인 정보:**
* **ID:** `admin`
* **PW:** `admin` (최초 접속 후 즉시 비밀번호 변경 창이 뜹니다.)



---

## 🚨 핵심 삽질 포인트

### 📍 삽질 1: "무한 로딩과 메모리 부족"

* **증상:** 파드는 `Running`인데 브라우저 접속이 안 되거나 매우 느림.
* **원인:** 소나큐브는 Java 기반이며 내부에 Elasticsearch까지 돌리기 때문에 메모리 2GB도 빠듯할 수 있습니다.
* **해결:** `kubectl logs -f <pod-name> -n sonarqube`를 확인하여 `Out of Memory` 에러가 난다면, 다른 불필요한 도구(ELK 등)를 잠시 멈추거나 VM 사양 상향을 고려해야 합니다.

### 📍 삽질 2: "DB 연결 실패 (PostgreSQL)"

* **증상:** 소나큐브 파드가 `CrashLoopBackOff` 상태이며 로그에 DB 에러 발생.
* **원인:** 함께 설치된 PostgreSQL 파드가 디스크(PV)를 할당받지 못해 실행되지 않은 경우입니다.
* **해결:** `kubectl get pvc -n sonarqube`를 확인하세요. `NFS Provisioner`가 없다면 `persistence.enabled: false`로 수정해야 합니다.

### 📍 삽질 3: "분석 결과 업로드 실패 (413 Request Entity Too Large)"

* **상황:** 젠킨스 등에서 분석 결과를 보내는데 용량 초과 에러 발생.
* **해결:** 인그레스 설정(`annotations`)에 `proxy-body-size` 설정이 정확히 들어갔는지 확인하세요.

---