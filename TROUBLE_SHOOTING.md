# 🛠 주요 트러블슈팅 및 해결 사례 (Troubleshooting Report)

본 프로젝트를 구축하며 직면했던 핵심 기술적 난제들과 이를 해결하며 도출한 최적화 방안을 기록합니다. 

---

## 1. 앤서블 SSH 접속 자동화 및 터널링 이슈
* **문제점**: Azure Private Subnet 내부에 위치한 마스터/워크 노드들에 앤서블이 직접 접속하지 못해 배포가 중단됨. 과거 방식처럼 모든 노드에 수동으로 `ssh-copy-id`를 수행하는 것은 자동화 및 보안 원칙에 위배됨.
* **해결책**:
    * **Bastion 호스트**를 유일한 외부 관문으로 설정하고 인프라 보안 강화.
    * `run.sh` 실행 시 앤서블에 `ProxyCommand`를 동적으로 주입하여 Bastion을 경유하는 **SSH 터널링** 자동화 구현.
    * Terraform의 Metadata 주입 기능을 통해 VM 생성과 동시에 호스트의 SSH 공개키가 자동 배포되도록 설계.



## 2. Kubeadm 인증서 및 엔드포인트 불일치
* **문제점**: 클러스터 구축 후 마스터 노드 외부에서 `kubectl` 명령 실행 시 타임아웃 또는 인증서 서명 오류(x509) 발생. 클라우드 사설 IP 대역과 외부 접속 엔드포인트 간의 정합성 문제 확인.
* **해결책**:
    * `kubeadm-config.yaml`의 `controlPlaneEndpoint`를 Azure Load Balancer 또는 마스터 사설 IP(`10.0.1.x`)로 표준화.
    * 인증서 생성 시 사설 IP 대역을 **SAN(Subject Alternative Names)**에 명시적으로 추가하여 노드 간 통신 및 외부 관리 통신에서의 보안 신뢰성 확보.

## 3. NFS 스토리지 동적 할당 실패 (IP 유동성 문제)
* **문제점**: NFS 서버 VM의 사설 IP가 배포 시마다 가변적일 수 있어, `nfs-values.yaml`에 고정된 IP 설정이 깨지는 현상 발생. 이로 인해 PVC가 `Pending` 상태에서 멈추는 리소스 할당 장애 발생.
* **해결책**:
    * `run.sh`에서 Terraform Output 기능을 통해 생성된 NFS 서버의 실제 사설 IP를 변수로 실시간 추출.
    * Helm 배포 명령어에 `--set nfs.server=$NFS_IP` 옵션을 추가하여, 정적 파일 수정 없이 실행 시점에 설정을 동적으로 주입하도록 파이프라인 최적화.

## 4. GitOps 경로 및 디렉토리 표준화 오류
* **문제점**: 초기 설계 단계에서 `argo-yaml`, `argo-cd` 등 폴더명이 혼용되어 ArgoCD Application이 배포 대상을 탐색하지 못하는 경로 오류 발생.
* **해결책**:
    * 프로젝트 전반의 배포 자산 폴더명을 `argoCd`로 단일화하여 가시성 및 관리 효율성 증대.
    * ArgoCD Application 설정(CRD)의 `path` 속성을 새 구조에 맞춰 수정하고, `run.sh` 내 배포 경로를 일괄 업데이트하여 전체 파이프라인의 정합성 완성.

---


