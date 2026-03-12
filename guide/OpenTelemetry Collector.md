**요약:**
분산된 메트릭, 트레이스, 로그를 하나의 파이프라인으로 묶어주는 **OpenTelemetry(OTel) Collector** 구축 가이드입니다. 특정 벤더에 종속되지 않고 데이터를 수집하여 Prometheus나 Jaeger 등 원하는 목적지로 쏴주는 '중계 기지' 역할을 합니다. 운영 표준에 맞춰 **Ingress-Nginx**를 통해 상태 확인 페이지(zPages)를 노출하도록 설정했습니다.

---

# 📡 Stage 7: OpenTelemetry Collector - 통합 데이터 파이프라인 구축 가이드

## 1. 사전 준비 (Prerequisites)

* **목적지 필요:** 데이터를 보낼 **Prometheus**(Stage 1)와 **Jaeger**(Stage 3)가 이미 설치되어 있어야 시너지가 납니다.

## 2. Helm 설정 파일 생성 (`otel-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# otel-values.yaml
mode: deployment # 중앙 수집기 모드

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
  
  processors:
    batch: # 데이터를 모아서 효율적으로 전송
    memory_limiter:
      check_interval: 1s
      limit_percentage: 80
      spike_limit_percentage: 25

  exporters:
    debug:
      verbosity: basic
    # [🔥핵심] 수집한 데이터를 앞서 설치한 도구들로 전달
    otlp/jaeger:
      endpoint: jaeger-collector.observability.svc.cluster.local:4317
      tls:
        insecure: true
    prometheus:
      endpoint: 0.0.0.0:8889

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlp/jaeger, debug]
      metrics:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [prometheus, debug]

# [🔥운영 표준] 내부 상태 확인 페이지(zPages) 노출용 인그레스
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
  hosts:
    - host: otel.20.196.204.108.nip.io # [본인의 공인IP로 수정]
      paths:
        - path: /
          pathType: Prefix
          port: 55679 # zPages 기본 포트

```

## 3. OTel Collector 설치 (Helm 실행)

마스터 서버 터미널에서 실행합니다.

```bash
# 1. 레포지토리 추가
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# 2. 설치 (네임스페이스: tracing)
helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace tracing --create-namespace \
  -f otel-values.yaml

```

## 4. 작동 확인

* **상태 확인 페이지:** `http://otel.20.196.204.108.nip.io/debug/tracez` 접속 시 현재 처리 중인 트레이스 정보를 볼 수 있습니다.
* **데이터 흐름 확인:** 애플리케이션에서 `4317`(gRPC) 포트로 데이터를 쏘면, Collector가 이를 받아 Jaeger로 넘겨주는지 로그를 통해 확인합니다.
```bash
kubectl logs -f <otel-pod-name> -n tracing

```



## 🚨 핵심 삽질 포인트

* **gRPC vs HTTP:** 애플리케이션 라이브러리 설정에 따라 `4317`과 `4318` 포트를 혼동하기 쉽습니다. 포트 번호와 프로토콜(gRPC/HTTP)이 일치하는지 반드시 확인해야 합니다.
* **메모리 제한 (Memory Limiter):** Collector는 중간에서 데이터를 버퍼링하므로 트래픽이 몰리면 메모리를 많이 먹습니다. `memory_limiter` 설정을 누락하면 파드가 예고 없이 죽을 수 있습니다.
* **TLS 설정:** 내부 통신 시 `tls.insecure: true` 설정을 하지 않으면, 별도의 인증서가 없는 환경에서 데이터 전송이 거부됩니다.

---