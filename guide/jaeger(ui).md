**요약:**
분산 트레이싱 도구인 **Jaeger**를 운영 표준(Ingress) 방식으로 구축하는 가이드입니다. `all-in-one` 배포 방식을 사용하여 빠르게 설치하며, **Ingress-Nginx**를 통해 포트 번호 없이 접속하도록 설정합니다.

---

# 🔍 Stage 3: Jaeger - 분산 트레이싱 구축 가이드

## 1. Helm 설정 파일 생성 (`jaeger-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# jaeger-values.yaml
allInOne:
  enabled: true
  ingress:
    enabled: true
    hosts:
      - jaeger.20.196.204.108.nip.io # [본인의 공인IP로 수정]
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"

# [참고] 나중에 Elasticsearch 연동 시 storageType을 변경합니다.
storage:
  type: memory # 실습용 (재시작 시 데이터 삭제)

```

## 2. Jaeger 설치 (Helm 실행)

마스터 서버 터미널에서 실행합니다.

```bash
# 1. 레포지토리 추가
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# 2. 설치 (네임스페이스: observability)
helm install jaeger jaegertracing/jaeger \
  --namespace observability --create-namespace \
  -f jaeger-values.yaml

```

## 3. 접속 확인

* **URL:** `http://jaeger.20.196.204.108.nip.io`
* **기능:** 서비스 간 호출 흐름(Trace) 및 지연 시간 시각화 확인.

## 🚨 핵심 삽질 포인트

* **메모리 제한:** `all-in-one` 모드는 트레이싱 데이터를 메모리에 쌓으므로, 데이터가 많아지면 파드가 OOM(Out Of Memory)으로 죽을 수 있습니다.
* **에이전트 포트:** 애플리케이션에서 트레이스를 보낼 때 사용하는 포트(UDP 6831 등)는 Ingress가 아닌 내부 Service IP를 통해 통신해야 합니다.

---