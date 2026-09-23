#!/bin/bash
# Eliminar los recursos aplicados de Flannel
kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
# Resetear el clúster de Kubernetes

sudo kubeadm reset -f

# Limpiar el estado del clúster
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/etcd
sudo rm -rf ~/.kube
sudo rm -rf /var/lib/kubelet/*

# Eliminar los recursos aplicados de Flannel
kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Reiniciar Docker y Kubelet
sudo systemctl restart docker
sudo systemctl restart kubelet

echo "Deshacer los cambios completado."
