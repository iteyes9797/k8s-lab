**요약:**
엘라스틱서치(Elasticsearch)에 저장된 로그를 시각화하고 분석하는 **키바나(Kibana)** 구축 가이드입니다. 앞서 구축한 엘라스틱서치(Stage 8)와 연동하며, 운영 표준인 **Ingress-Nginx**를 통해 포트 번호 없이 `kibana.<IP>.nip.io` 주소로 접속하도록 설정했습니다.

---

# 🎨 Stage 9: Kibana - 로그 시각화 및 탐색 구축 가이드

## 1. 사전 준비 (Prerequisites)

* **Elasticsearch:** 데이터를 제공할 엘라스틱서치(Stage 8)가 반드시 `Running` 상태여야 합니다.
* **네트워크:** 80/443 포트 개방 및 인그레스 컨트롤러 설치 확인.

---

## 2. Helm 설정 파일 생성 (`kibana-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# kibana-values.yaml
elasticsearchHosts: "http://elasticsearch-master:9200"

# 실습 환경(DS2_v2) 사양에 맞춘 리소스 제한
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "1Gi"

# 운영 표준 인그레스 설정
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
  hosts:
    - host: kibana.20.196.204.108.nip.io # [🔥본인의 공인IP로 수정]
      paths:
        - path: /

```

---

## 3. Kibana 설치 (Helm 실행)

마스터 서버 터미널에서 실행합니다.

```bash
# 1. 레포지토리 업데이트 (이미 추가되어 있음)
helm repo update

# 2. 설치 (네임스페이스: logging)
helm install kibana elastic/kibana \
  --namespace logging \
  -f kibana-values.yaml

```

---

## 4. 접속 확인

* **URL:** `http://kibana.20.196.204.108.nip.io`
* **확인:** 화면 로딩 후 "Welcome to Elastic" 메시지가 나오면 성공입니다.
* **초기 설정:** [Management] -> [Stack Management] -> [Index Patterns]에서 `fluentd-*` 등의 인덱스를 등록하여 로그를 조회할 수 있습니다.

---

## 🚨 핵심 삽질 포인트

### 📍 삽질 1: "Kibana server is not ready yet"

* **증상:** 브라우저 접속 시 위 메시지만 나오고 화면이 뜨지 않음.
* **원인:** 키바나가 엘라스틱서치에 연결을 시도 중이거나, 엘라스틱서치가 메모리 부족으로 응답이 느린 경우입니다.
* **해결:** 엘라스틱서치 파드 상태(`kubectl get pods -n logging`)를 확인하고 2~3분 정도 기다려 보세요.

### 📍 삽질 2: "엘라스틱서치 주소 불일치"

* **증상:** 키바나 로그에 `No Living connections` 에러 발생.
* **해결:** `elasticsearchHosts`에 적은 서비스 이름이 실제 엘라스틱서치 서비스 이름(`kubectl get svc -n logging`)과 일치하는지 확인하세요.

### 📍 삽질 3: "OOM (Out Of Memory)"

* **상황:** 키바나가 실행 중에 자꾸 꺼짐.
* **교훈:** Azure DS2_v2 사양에서 ELK 스택 전체를 돌리기에는 메모리가 타이트합니다. 불필요한 다른 파드들을 잠시 내리거나 리소스 제한을 더 낮게 조정해야 할 수도 있습니다.

---
