#!/bin/bash
# Desinstalar microk8s sin rastros
sudo microk8s stop
sudo snap remove microk8s 
sudo rm -rf /var/snap/microk8s/
sudo rm -rf ~/snap/microk8s/
sudo rm -rf /etc/microk8s/
sudo rm -rf /var/snap/microk8s/common/
sudo reboot

# Instalar Docker
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
#K8s@2024
# Desactivar memoria virtual o de intercambio
sudo swapoff -a # Desactivar la memoria de intercambio
sudo sed -i 's/^.*swap.*$/#&/' /etc/fstab # Desactivar la memoria de intercambio de forma permanente al reiniciar

# Actualizar el sistema
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Agregar repositorio de Kubernetes y su llave GPG
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Descargar e instalar kubeadm, kubelet y kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl


# Inicializar el nodo MAESTRO sin ser worker solo master
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 # Minikube usa minikube start --driver=docker
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml # Instalar un plugin de red (por ejemplo, Calico): # Calico es un plugin de red que permite la comunicación entre los pods y es mejor que flannel por que tiene más funcionalidades

# kubeadmin me mostrara el comando para unir los nodos trabajadores (debemos copiarlo pero no ejecutarlo)
# kubeadm join <ip_master>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
# Ejemplo
kubeadm join 10.1.116.30:6443 --token jb5xps.8sqlfi7bowp9llb3 --discovery-token-ca-cert-hash sha256:15370212ff77a475318a8c8055c62ab25e063eddd588b2ebecdd6c730d4cc6d1 


# Si los puertos estan ocupados al ejecutar el comando anterior sudo kubeadm init --pod-network-cidr=10.244.0.0/16 ejecute:
sudo lsof -i :10259 -i :10257 -i :10250



# Configurar kubectl para el usuario no root con certificados del nodo maestro 
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config # Copiar el archivo de configuración de kubectl con los certificados del nodo maestro
sudo chown $(id -u):$(id -g) $HOME/.kube/config # Cambiar el propietario del archivo de configuración de kubectl para que al ejecutarlo lo lea

# Unir nodos trabajadores
# kubeadm join <ip_master>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Verificar el estado del nodo
kubectl get nodes

# Configurar mi master para que también sea un worker
kubectl taint nodes --all node-role.kubernetes.io/master-

echo "Instalación de Kubernetes completada."

