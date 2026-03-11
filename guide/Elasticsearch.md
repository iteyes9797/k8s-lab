**요약:**
로그와 데이터를 저장하는 분산 검색 엔진 **Elasticsearch** 구축 가이드입니다. 직접 구축한 VM 환경의 사양(DS2_v2)을 고려하여 **싱글 노드(Single Node)**로 구성하였으며, 운영 표준인 **Ingress-Nginx**를 통해 API에 접속하도록 설정했습니다. (사실 확인 완료: Elasticsearch는 자바 기반으로 메모리 점유율이 높으며, 파드 실행 전 호스트 커널 파라미터(`vm.max_map_count`) 수정이 필수입니다.)

---

# 🔍 Stage 8: Elasticsearch - 분산 검색 엔진 구축 가이드

## 1. 사전 작업 (호스트 커널 설정)

Elasticsearch 파드가 정상적으로 실행되려면 **모든 노드(VM)**에서 아래 명령어를 반드시 실행해야 합니다. (설정하지 않으면 파드가 실행 중 에러로 죽습니다.)

```bash
# 모든 노드 터미널에서 실행
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

```

## 2. Helm 설정 파일 생성 (`elasticsearch-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# elasticsearch-values.yaml
replicas: 1
minimumMasterNodes: 1

# 실습 환경 사양에 맞춘 리소스 제한 (메모리 7GB 환경 고려)
resources:
  requests:
    cpu: "500m"
    memory: "2Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

# 자바 힙 사이즈 설정 (메모리의 절반 권장)
esJavaOpts: "-Xmx1g -Xms1g"

# 저장소 설정 (NFS Provisioner가 없다면 false로 수정하여 테스트 가능)
persistence:
  enabled: true
  size: 10Gi

# 운영 표준 인그레스 설정
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
  hosts:
    - host: elastic.20.196.204.108.nip.io # [본인의 공인IP로 수정]
      paths:
        - path: /

```

## 3. Elasticsearch 설치 (Helm 실행)

마스터 서버 터미널에서 실행합니다.

```bash
# 1. 레포지토리 추가
helm repo add elastic https://helm.elastic.co
helm repo update

# 2. 설치 (네임스페이스: logging)
helm install elasticsearch elastic/elasticsearch \
  --namespace logging --create-namespace \
  -f elasticsearch-values.yaml

```

## 4. 접속 확인

* **URL:** `http://elastic.20.196.204.108.nip.io`
* **확인:** 브라우저 접속 시 Elasticsearch의 버전 정보와 "You Know, for Search" 문구가 포함된 JSON 결과가 나오면 성공입니다.

## 🚨 핵심 삽질 포인트

* **Pending 상태:** `NFS Provisioner`가 설치되지 않은 상태에서 `persistence.enabled: true`로 배포하면 파드가 `Pending`에 멈춥니다. 당장 확인하려면 `false`로 바꾸고 다시 설치하세요.
* **vm.max_map_count:** 파드 로그에 `max virtual memory areas vm.max_map_count [65530] is too low` 에러가 보인다면 1번 단계의 커널 설정을 누락한 것입니다.
* **초기 비밀번호:** 최근 버전은 보안이 기본 적용되어 비밀번호를 물어볼 수 있습니다. 아래 명령어로 확인하세요.
```bash
kubectl get secret -n logging elasticsearch-master-credentials -o jsonpath="{.data.password}" | base64 -d; echo

```

