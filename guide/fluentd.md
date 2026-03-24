**요약:**
쿠버네티스 노드 전체의 로그를 수집하여 전달하는 **Fluentd** 구축 가이드입니다. Fluentd는 웹 UI가 없는 백엔드 데몬(DaemonSet)이므로, 각 노드에 하나씩 배치되어 `/var/log/containers`의 로그를 긁어 모으는 역할을 합니다.

---

# 🪵 Stage 6: Fluentd - 통합 로그 수집기 구축 가이드

## 1. 사전 준비 (Prerequisites)

* **목적지 필요:** Fluentd는 로그를 '수집'해서 '전달'하는 도구입니다. 나중에 설치할 **Elasticsearch**가 주 목적지가 되지만, 현재는 설치 전이므로 기본 설정으로 배포합니다.

## 2. Helm 설정 파일 생성 (`fluentd-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# fluentd-values.yaml
deploymentMode: daemonset # 모든 노드에 하나씩 배포

# [🔥핵심] 로그 파일 권한 설정
fileConfigs:
  01_sources.conf: |-
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      read_from_head true
      <parse>
        @type json
      </parse>
    </source>

# [참고] Elasticsearch 설치 후 아래 output 설정을 활성화합니다.
outputConfigs:
  01_outputs.conf: |-
    <match **>
      @type stdout # 현재는 테스트를 위해 표준 출력(로그창)에만 뿌림
    </match>

```

## 3. Fluentd 설치 (Helm 실행)

마스터 서버 터미널에서 실행합니다.

```bash
# 1. 레포지토리 추가
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# 2. 설치 (네임스페이스: logging)
helm install fluentd fluent/fluentd \
  --namespace logging --create-namespace \
  -f fluentd-values.yaml

```

## 4. 작동 확인

Fluentd는 UI가 없으므로 **파드의 로그**를 통해 수집 여부를 확인합니다.

```bash
# 1. 파드 이름 확인
kubectl get pods -n logging

# 2. 실제 로그 수집 여부 확인
# 다른 서비스들의 로그가 화면에 쏟아진다면 정상입니다.
kubectl logs -f <fluentd-pod-name> -n logging

```

## 🚨 핵심 삽질 포인트

* **권한 문제 (RBAC):** Fluentd가 `/var/log` 밑의 호스트 로그 파일을 읽으려면 시스템 권한이 필요합니다. Helm 설치 시 `rbac.create: true` 옵션(기본값)이 켜져 있어야 합니다.
* **리소스 부하:** 모든 로그를 수집하면 CPU 점유율이 올라갈 수 있습니다. `resources` 제한을 걸어두는 것이 운영상 안전합니다.
* **Pos 파일:** Fluentd가 재시작되어도 어디까지 읽었는지 기억하는 `pos_file`이 호스트 경로에 잘 생성되는지 확인해야 합니다.

---