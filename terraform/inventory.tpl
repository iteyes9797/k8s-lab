# ==============================================================================
# [정적 인벤토리 템플릿 - Bastion 분리형 구조]
# Terraform에 의해 사설 IP와 Bastion 공인 IP가 주입됩니다.
# ==============================================================================

[masters]
k8s-master01 ansible_host=${master1}
k8s-master02 ansible_host=${master2}
k8s-master03 ansible_host=${master3}

[workers]
k8s-worker01 ansible_host=${worker1}
k8s-worker02 ansible_host=${worker2}

[nfs]
k8s-nfs01 ansible_host=${nfs}

[lb]
k8s-lb01 ansible_host=${lb}

[bastion]
bastion-host ansible_host=${bastion_ip}

[all:vars]
ansible_user=azureuser
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3

ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ForwardAgent=yes'

[masters:vars]
ansible_ssh_common_args='-o ProxyJump=azureuser@${bastion_ip} -o StrictHostKeyChecking=no -o ForwardAgent=yes'

[workers:vars]
ansible_ssh_common_args='-o ProxyJump=azureuser@${bastion_ip} -o StrictHostKeyChecking=no -o ForwardAgent=yes'

[nfs:vars]
ansible_ssh_common_args='-o ProxyJump=azureuser@${bastion_ip} -o StrictHostKeyChecking=no -o ForwardAgent=yes'

[lb:vars]
ansible_ssh_common_args='-o ProxyJump=azureuser@${bastion_ip} -o StrictHostKeyChecking=no -o ForwardAgent=yes'