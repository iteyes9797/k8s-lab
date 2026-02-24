**두 SSH 키는 서로 다른 용도와 역할을 가집니다.** 하지만 둘 다 "패스워드 없이 접속"을 위한 것은 동일합니다.

### 1. Terraform의 SSH 키 (`~/.ssh/id_rsa.pub`)
*   **역할**: Terraform이 애저(Azure)에서 VM을 **생성할 때 VM 안에 미리 심어넣는** 공개키입니다.
*   **누가 쓰는가?**: 아키텍트(사용자)가 생성된 **VM에 처음 SSH 접속할 때** 사용합니다.
    *   (내 PC) --[SSH]--> (생성된 VM)
*   **기본값**: 보통 RSA 방식(`id_rsa`)을 많이 쓰지만, ED25519도 가능합니다.

### 2. Ansible의 SSH 키 (`~/.ssh/id_ed25519`)
*   **역할**: Ansible **Control Node(제어 노드)** 가 관리 대상 **Managed Node(서버들)** 에 접속하여 **설정을 변경할 때** 사용하는 키입니다.
*   **누가 쓰는가?**: Ansible이 **자동화 작업을 수행할 때** 사용합니다.
    *   (Control Node) --[SSH]--> (Managed Node: Master/Worker 등)
*   **구성 방법**:
    1.  Control Node에서 `ssh-keygen`으로 키 생성
    2.  `ssh-copy-id` 명령어로 각 서버에 키 복사
    3.  이후 패스워드 없이 자동 접속 가능

### **결론: 어떻게 설정해야 할까요?**

만약 **아키텍트 PC(내 컴퓨터)** 에서 Terraform을 실행하고, 동시에 Ansible도 로컬에서 돌린다면 **같은 키를 사용해도 됩니다.**

1.  **하나의 키만 생성**: `ssh-keygen -t rsa -b 4096`
2.  **Terraform**: compute.tf에 `~/.ssh/id_rsa.pub` 경로 지정 (VM 생성 시 자동 배포됨)
3.  **Ansible**: ansible.cfg나 인벤토리에 `ansible_ssh_private_key_file=~/.ssh/id_rsa` 설정
    *   Terraform이 이미 VM에 키를 심어줬으므로, 별도의 `ssh-copy-id` 과정 없이 바로 접속 가능합니다!

**추천**: 관리의 편의성을 위해 **RSA 키(`id_rsa`) 하나로 통일**하여 사용하는 것이 가장 간편합니다. compute.tf와 Ansible 설정 모두 `~/.ssh/id_rsa`를 바라보게 하세요.