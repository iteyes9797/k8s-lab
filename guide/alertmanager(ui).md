**요약:**
프로메테우스가 감지한 이상 징후를 분류하고 알림(Slack, Email 등)으로 전달하는 **AlertManager** 구축 가이드입니다. 운영 표준인 **Ingress-Nginx**를 통해 포트 번호 없이 접속하도록 설정합니다.

---

# 🔔 Stage 5: AlertManager - 알람 통합 관리 구축 가이드

## 1. 사전 준비 (Prerequisites)

* **Prometheus:** 알람 규칙(Alerting Rules)을 생성하고 AlertManager로 전송할 프로메테우스가 필요함 (Stage 1에서 설치 완료).

## 2. Helm 설정 파일 생성 (`alertmanager-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# alertmanager-values.yaml
config:
  global:
    resolve_timeout: 5m
  route:
    group_by: ['alertname']
    group_wait: 10s
    group_interval: 10s
    repeat_interval: 1h
    receiver: 'default-receiver'
  receivers:
    - name: 'default-receiver'
      # [참고] 실무에서는 여기에 Slack이나 Email 설정을 넣습니다.
      # 지금은 테스트를 위해 설정을 비워두거나 log로 확인합니다.

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: alertmanager.20.196.204.108.nip.io # [본인의 공인IP로 수정]
      paths:
        - path: /
          pathType: ImplementationSpecific
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"

persistence:
  enabled: true
  size: 2Gi # 알람 상태 및 무음(Silence) 설정을 저장하기 위한 디스크

```

## 3. AlertManager 설치 (Helm 실행)

마스터 서버 터미널에서 실행합니다.

```bash
# 1. 레포지토리 추가 (이미 되어있다면 업데이트만)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. 설치 (네임스페이스: monitoring)
helm install alertmanager prometheus-community/alertmanager \
  --namespace monitoring \
  -f alertmanager-values.yaml

```

## 4. 접속 확인

* **URL:** `http://alertmanager.20.196.204.108.nip.io`
* **확인:** 현재 발생한 알람(Alerts) 목록과 무음 처리(Silences) 설정 화면 확인.

## 🚨 핵심 삽질 포인트

* **Config 문법 에러:** AlertManager는 설정 파일(`config`)의 들여쓰기나 문법에 매우 민감합니다. 설정 변경 후 파드가 `CrashLoopBackOff`에 빠진다면 `kubectl logs`로 문법 에러를 확인하세요.
* **프로메테우스 연동:** 프로메테우스의 `values.yaml`에서 AlertManager의 주소를 정확히 가리켜야 합니다.
* 예: `alertmanager_url: http://alertmanager.monitoring.svc.cluster.local:9093`


* **Persistent Volume:** NFS Provisioner가 없는 환경이라면 파드가 `Pending` 상태가 됩니다. 당장 테스트가 급하다면 `persistence.enabled: false`로 임시 설치하세요.

---