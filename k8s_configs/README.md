# Kubernetes Configurations

이 디렉토리는 Kubernetes 클러스터의 초기화(init) 과정에서 생성되거나, 클러스터 관리에 사용되는 주요 설정 파일들을 포함하고 있습니다.

## 파일 목록 및 설명

| 파일명 | 설명 |
|---|---|
| **`admin.conf`** | 클러스터 관리자(Administrator) 권한을 가진 Kubeconfig 파일입니다. `kubectl`을 통해 클러스터를 제어할 때 사용됩니다. |
| **`super-admin.conf`** | `admin.conf`보다 상위 권한을 가지거나, 초기 부트스트래핑 시 생성된 최고 관리자 설정 파일입니다. (Kubernetes 버전에 따라 `admin.conf`와 분리되어 생성될 수 있음) |
| **`kubeadm-config.yaml`** | `kubeadm init` 명령 실행 시 사용하는 클러스터 초기화 설정 파일입니다. API 서버 주소, 네트워크 대역(Pod/Service CIDR), 사용될 컨테이너 런타임 소켓 등이 정의되어 있습니다. |
| **`controller-manager.conf`** | Kubernetes Controller Manager 컴포넌트가 API 서버와 통신하기 위한 설정 파일입니다. |
| **`scheduler.conf`** | Kubernetes Scheduler 컴포넌트가 API 서버와 통신하기 위한 설정 파일입니다. |
| **`kubelet.conf`** | 각 노드의 Kubelet 에이전트가 API 서버와 통신하기 위한 설정 파일입니다. (주로 부트스트랩 토큰 인증 등에 사용됨) |
| **`kubectl`** | Kubernetes 클러스터 제어를 위한 CLI 도구 바이너리 또는 실행 스크립트입니다. |

## 사용 방법

### `kubectl` 설정 적용 (admin.conf)

로컬 머신이나 관리 노드에서 `kubectl`을 사용하여 이 클러스터에 접속하려면, `admin.conf` 파일을 사용자의 `.kube/config` 경로로 복사하거나 환경 변수를 설정해야 합니다.

**방법 1: 환경 변수 설정 (일회성)**
```bash
export KUBECONFIG=$(pwd)/admin.conf
kubectl get nodes
```

**방법 2: 설정 파일 복사 (영구 적용)**
```bash
mkdir -p $HOME/.kube
cp -i admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

> **주의:** 이 폴더에 포함된 파일들은 클러스터의 관리자 인증 정보(`client-certificate-data`, `client-key-data`)를 포함하고 있으므로, 보안에 유의하여 관리해야 합니다. 외부 유출 시 클러스터 보안이 침해될 수 있습니다.
