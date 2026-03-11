[쿠버네티스 개발 VM 사용 안내 – NodePort 방식]

────────────────────────────────────────
1. 서버 정보
────────────────────────────────────────
192.168.0.106   k8s-master01 (kubectl 사용 가능)
192.168.0.107   k8s-master02
192.168.0.108   k8s-master03
192.168.0.109   nfs
192.168.0.110   lb-proxy
192.168.0.111   k8s-worker01
192.168.0.112   k8s-worker02

각 서버 계정
ID: root 또는 rocky
PW: iteyes7979!@

모든 작업은 기본적으로
- Putty로 k8s-master01 (192.168.0.106)에 접속한 뒤
- 그 안에서 kubectl 명령어를 사용합니다.
────────────────────────────────────────
2. DB접속정보 
────────────────────────────────────────


DB 접속정보(MariaDB)

호스트: 192.168.0.111
포트: 30306 
rootPassword: "rootpassword123!"
database: "appdb"
username: "appuser"
password: "appuserpassword123!"

────────────────────────────────────────
2. 현재 실행 중인 “개발 VM(컨테이너)” 확인
────────────────────────────────────────
k8s-master01에 접속 후:

kubectl get pods -n dev-vm

출력 예:
dev-app-xxxx
dev-was-xxxx
dev-smartcontract-xxxx
dev-web-nginx-xxxx

여기서 xxxx 부분이 실제 Pod 이름입니다.
이 이름을 이후 명령어에 그대로 사용합니다.

────────────────────────────────────────
3. 컨테이너 안으로 들어가기 (VM 접속 느낌)
────────────────────────────────────────
각 컨테이너는 “개발용 VM”처럼 사용합니다.
SSH 대신 kubectl exec로 접속합니다.

dev-app 접속:
kubectl exec -it -n dev-vm dev-app-xxxx -- sh

dev-was 접속:
kubectl exec -it -n dev-vm dev-was-xxxx -- sh

dev-smartcontract 접속:
kubectl exec -it -n dev-vm dev-smartcontract-xxxx -- sh

dev-web-nginx 접속:
kubectl exec -it -n dev-vm dev-web-nginx-xxxx -- sh

※ xxxx는 `kubectl get pods -n dev-vm` 결과에서 복사해서 사용

접속되면 일반 리눅스 서버에 SSH로 들어온 것처럼
ls, cd, vi, java, curl 등의 명령을 그대로 사용할 수 있습니다.

────────────────────────────────────────
4. 파일 복사 방법 (scp 대신 kubectl cp 사용)
────────────────────────────────────────
직접 SSH가 안 되므로, 파일 전송은 kubectl cp를 사용합니다.

(1) 로컬 PC → k8s-master01
- WinSCP 등으로 192.168.0.106에 파일 업로드
  예: /tmp/app.jar 에 업로드

(2) k8s-master01 → 컨테이너(dev-app 예시)

kubectl cp /tmp/app.jar dev-vm/dev-app-xxxx:/workspace/app.jar

(3) 컨테이너 → k8s-master01 (로그 등 회수)

kubectl cp dev-vm/dev-app-xxxx:/workspace/app.log /tmp/app.log

이 방식으로
- 소스
- jar/war 파일
- 설정 파일
- 로그 파일
등을 자유롭게 주고받을 수 있습니다.

────────────────────────────────────────
5. 컨테이너 안에서 애플리케이션 실행
────────────────────────────────────────
예: dev-app에서 jar 실행

kubectl exec -it -n dev-vm dev-app-xxxx -- sh

컨테이너 안에서:
cd /workspace
java -jar app.jar

현재 구조는 컨테이너가 항상 떠 있도록 되어 있으므로,
직접 들어가서 실행하는 방식입니다.

────────────────────────────────────────
6. 서비스 접근 방법 (NodePort 방식)
────────────────────────────────────────
외부에서 접근할 때는 “워커 노드 IP + NodePort”를 사용합니다.
어느 워커 노드 IP로 접근해도 됩니다.

현재 설정된 포트:

dev-app-svc
- 내부 8080 → 외부 32280

dev-was-svc
- 내부 8080 → 외부 32180

dev-smartcontract-svc
- 내부 8080 → 외부 32380

dev-web-nginx-svc
- 내부 80 → 외부 32080

접속 예시 (회사 내부망에서):

dev-app:
http://192.168.0.111:32280
http://192.168.0.112:32280

dev-was:
http://192.168.0.111:32180

dev-smartcontract:
http://192.168.0.111:32380

dev-web-nginx:
http://192.168.0.111:32080


1) 접속(쉘):
kubectl exec -it -n dev-vm <pod이름> -- sh

2) 파일 전송:
kubectl cp 로컬파일 dev-vm/<pod이름>:/경로

3) 서비스 접근:
http://<워커노드IP>:<NodePort>
