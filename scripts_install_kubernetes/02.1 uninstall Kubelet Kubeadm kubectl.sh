#!/bin/bash

# Detener kubelet
sudo systemctl stop kubelet

# Deshacer la retención de los paquetes
sudo apt-mark unhold kubelet kubeadm kubectl

# Purgar los paquetes de Kubernetes
sudo apt-get purge -y kubelet kubeadm kubectl
sudo apt-get autoremove -y

# Eliminar directorios de configuración y datos
sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/kubelet
sudo rm -rf ~/.kube

echo "Paquetes de Kubernetes eliminados y configuración limpiada."
