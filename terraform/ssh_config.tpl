Host bastion
    HostName ${bastion_ip}
    User azureuser
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no

Host k8s-*
    User azureuser
    IdentityFile ~/.ssh/id_rsa
    ProxyJump bastion
    StrictHostKeyChecking no

Host k8s-master01
    HostName ${master1}
Host k8s-master02
    HostName ${master2}
Host k8s-master03
    HostName ${master3}
Host k8s-worker01
    HostName ${worker1}
Host k8s-worker02
    HostName ${worker2}
Host k8s-nfs01
    HostName ${nfs}
Host k8s-lb01
    HostName ${lb}