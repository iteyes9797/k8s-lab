**요약:**
대규모 데이터를 실시간으로 수집하고 처리하는 분산 메시지 브로킹 플랫폼 **Kafka** 구축 가이드입니다. 이전 단계에서 구축한 **NFS Provisioner(Stage 23)**를 저장소로 활용하며, 메모리 효율을 위해 주키퍼(Zookeeper)가 필요 없는 **KRaft 모드**로 배포합니다. 운영 표준인 **Ingress-Nginx**를 통해 외부 통신이 가능하도록 설정했습니다. (사실 확인 완료: Kafka KRaft 모드는 최신 버전에서 운영 환경 사용이 가능하며, 외부 접속을 위해선 `advertised.listeners` 설정이 인그레스 도메인과 반드시 일치해야 합니다.)

---

# 🎡 Stage 24: Kafka - 실실간 데이터 스트리밍 플랫폼 구축 가이드

## 1. 개요

* **역할:** 서비스 간의 결합도를 낮추고, 대량의 데이터를 유실 없이 전달하는 '데이터 고속도로' 역할을 합니다.
* **특징:** 고성능, 확장성, 영속성(메시지를 디스크에 저장)이 뛰어나 로그 수집 및 실시간 분석에 필수적입니다.

---

## 2. Helm 설정 파일 생성 (`kafka-values.yaml`)

실습 환경(DS2_v2)의 메모리 압박을 고려하여 **1개의 브로커**만 띄우는 가벼운 구성입니다.

```yaml
# kafka-values.yaml
# [🔥핵심] Zookeeper 없이 실행하는 KRaft 모드 활성화
kraft:
  enabled: true

replicaCount: 1

# 리소스 제한 (JVM 힙 메모리 포함)
resources:
  requests:
    cpu: "250m"
    memory: "1Gi"
  limits:
    cpu: "500m"
    memory: "1Gi"

# 저장소 설정 (Stage 23에서 만든 nfs-client 사용)
persistence:
  enabled: true
  storageClass: "nfs-client"
  size: 10Gi

# [🔥운영 표준] 외부 접속을 위한 Ingress 설정
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "TCP" # Kafka는 TCP 통신
  hostname: kafka.20.196.204.108.nip.io # [본인의 공인IP로 수정]

# Kafka 외부 광고 설정 (외부에서 접속할 때 필요한 주소)
externalAccess:
  enabled: true
  controller:
    service:
      type: NodePort

```

---

## 3. Kafka 설치 (Helm 실행)

Bitnami 차트가 KRaft 모드를 가장 안정적으로 지원합니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. 설치 (네임스페이스: kafka)
helm install kafka bitnami/kafka \
  --namespace kafka --create-namespace \
  -f kafka-values.yaml

```

---

## 4. 메시지 송수신 테스트

카프카가 정상적으로 메시지를 빨아들이는지 확인해 봅시다.

```bash
# 1. 메시지 생산자(Producer) 실행
kubectl exec -it kafka-0 -n kafka -- kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-topic

# > 여기에 메시지 입력 (예: Hello Kafka!) 후 Enter, 종료는 Ctrl+C

# 2. 메시지 소비자(Consumer) 실행
kubectl exec -it kafka-0 -n kafka -- kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --from-beginning

```

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "메모리 부족 (Heap Size)"

* **증상:** 파드는 떴는데 조금 뒤에 `Terminated (OOMKilled)`가 뜸.
* **원인:** 카프카는 기본적으로 JVM 힙 메모리를 많이 잡으려 합니다.
* **해결:** `KAFKA_HEAP_OPTS` 환경 변수를 통해 `-Xmx512M -Xms512M` 정도로 낮게 잡아주세요. (Values 파일에서 조정 가능)

### 📍 삽질 2: "외부 클라이언트 접속 불가"

* **상황:** 내 로컬 PC에서 카프카 주소로 접속하려는데 연결 거부됨.
* **원인:** 카프카 브로커는 `advertised.listeners`에 적힌 주소를 클라이언트에게 알려줍니다. 이 주소가 도메인이 아닌 내부 IP로 되어 있으면 외부 접속이 불가능합니다.
* **해결:** Ingress 설정과 함께 `externalAccess` 설정을 정확히 매칭시켜야 합니다.

### 📍 삽질 3: "Disk Full (로그 보존 정책)"

* **상황:** 설치한 지 며칠 지나니 NFS 용량이 꽉 참.
* **해결:** 실습 환경에서는 메시지 보존 기간(`log.retention.hours`)을 짧게(예: 1시간) 설정하거나 용량 제한(`log.retention.bytes`)을 걸어두는 것이 정신 건강에 이롭습니다.

---