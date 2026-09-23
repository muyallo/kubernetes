#!/bin/bash

# Fija el hostname directamente en el script
HOSTNAME="mi-hostname-ejemplo"

# Verifica si el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor ejecuta este script como root o usando sudo."
  exit 1
fi

# Configurar el hostname
echo "Configurando hostname: $HOSTNAME"
sudo hostnamectl set-hostname "$HOSTNAME"

# Actualizar el sistema operativo
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# Desactivar swap
echo "Desactivando swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Instalar dependencias básicas
echo "Instalando herramientas básicas..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg chrony

# Sincronizar tiempo
echo "Configurando sincronización de tiempo..."
sudo systemctl enable chrony
sudo systemctl start chrony

# Configurar módulos del kernel
echo "Configurando módulos del kernel necesarios para Kubernetes..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Instalar Docker
echo "Instalando Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker

# Configurar containerd para Kubernetes
echo "Configurando containerd para Kubernetes..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Configurar repositorio de Kubernetes
echo "Añadiendo repositorio de Kubernetes..."
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /et
