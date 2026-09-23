#VIRTUALBOX
DISTRO_VERSION=$(lsb_release -c | awk '{print $2}')
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $DISTRO_VERSION contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor | sudo tee /usr/share/keyrings/oracle-virtualbox-2016.gpg > /dev/null
sudo apt-get update
sudo apt search virtualbox
sudo apt-get install -y virtualbox-7.1
wget https://download.virtualbox.org/virtualbox/7.1.4/Oracle_VirtualBox_Extension_Pack-7.1.4.vbox-extpack
sudo VBoxManage extpack install Oracle_VirtualBox_Extension_Pack-7.1.4.vbox-extpack
rm -vfr Oracle_VirtualBox_Extension_Pack-7.1.4.vbox-extpack
sudo groupadd vboxusers
sudo usermod -aG vboxusers $USER
newgrp vboxusers
groups $USER
groups


# OPTIMIZACION KDE PARA INSTALAR KUBERNETES
sudo systemctl set-default multi-user.target
# Desactiva el gestor de display gráfico
sudo systemctl disable sddm.service
echo 'echo "Iniciar entorno de escritorio: sudo systemctl start sddm"' >> ~/.bashrc
# Service
sudo systemctl stop bluetooth.service
sudo systemctl disable bluetooth.service
sudo systemctl disable cups.service
sudo systemctl stop cups.service
# Optimización de memoria
# sudo sysctl vm.swappiness=10
# echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
# sudo sysctl vm.dirty_ratio=10
# echo "vm.dirty_ratio=10" | sudo tee -a /etc/sysctl.conf
# sudo sysctl vm.dirty_background_ratio=5
# echo "vm.dirty_background_ratio=5" | sudo tee -a /etc/sysctl.conf
sudo swapoff -a
sudo sed -i 's/^.*swap.*$/#&/' /etc/fstab
sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cgroup_enable=memory swapaccount=1"/' /etc/default/grub
sudo update-grub
#Gestión de paquetes
sudo apt autoremove -y


#SSH
sudo -v
sudo apt update && sudo apt upgrade -y
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh
echo "$(hostname) $(hostname -I | awk '{print $1}')"
ip_address=$(hostname -I | awk '{print $1}')
echo "Usa: ssh andres@$ip_address"
echo -e "\nTen presente usar: \n sudo hostnamectl set-hostname worker"


#DOCKER
sudo apt install apt-transport-https curl docker.io docker-compose-v2 -y
sudo systemctl  enable --now docker



#CONTAINERD
sudo apt install containerd -y
sudo systemctl enable --now containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd


#KUBERNETES
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
sudo apt install -y apt-transport-https ca-certificates curl gpg docker.io docker-compose-v2
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
kubelet --version
kubeadm version
kubectl version --client

#Reiniciar
sudo reboot now


# KUBERNETES MASTER  ---  KUBERNETES MASTER  ---  KUBERNETES MASTER  ---  KUBERNETES MASTER

# Inicialización del nodo maestro
sudo kubeadm init --pod-network-cidr=10.244.0.0/16


# COPIAR EL COMANDO - COPIAR EL COMANDO - COPIAR EL COMANDO
kubeadm join 192.168.1.56:6443 --token z6pd3z.7l2dgfsr81l9nstm \
	--discovery-token-ca-cert-hash sha256:195ed334b8c75cda8b3d03d2be04f212ec2dad186686d24b3e0dac6d34dfc2bd 


# Configurar kubectl para el usuario 
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl restart docker

#Instalar el CNI (red de contenedores)
#kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
# Calico
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml







#Esperar 2 a 8 minutos Verificar el estado del clúster
kubectl get nodes
kubectl get pods --all-namespaces
#Copia y obtén el comando de unión para los nodos trabajadores
#kubeadm join <MAESTRO_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>









# KUBERNETES WORKER
sudo kubeadm join <master-ip>:<port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
kubectl get nodes

#VERIFICACIÓN FINAL
#Confirmar funcionamiento Flannel
kubectl get pods -n kube-system
#Prueba de conectividad con ejemplo simple de nginx
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
#Luego, verifica el servicio y accede al puerto expuesto:
kubectl get svc
kubectl get pods
kubectl get nodes



# Actualizar K8s

sudo apt-mark unhold kubelet kubeadm kubectl
sudo apt-get remove --purge -y kubelet kubeadm kubectl
sudo sed -i 's|core:/stable:/v1.30|core:/stable:/v1.32|' /etc/apt/sources.list.d/kubernetes.list
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
kubelet --version
kubeadm version
kubectl version --client
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl restart docker







# Verificar los pods del clúster (especialmente el kube-apiserver)
kubectl get pods -n kube-system
kubectl delete pod kube-apiserver-master -n kube-system
kubectl logs kube-apiserver-master -n kube-system


# Resetear Mi master

sudo kubectl delete -f https://github.com/coreos/flannel/releases/download/v0.19.0/kube-flannel.yml
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/*
sudo rm -rf /var/lib/etcd/*
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /opt/cni/*
sudo rm -rf /etc/cni/*
sudo docker system prune -af
sudo systemctl stop kubelet
sudo systemctl stop docker
sudo systemctl start docker
sudo systemctl start kubelet
sudo kubeadm init --pod-network-cidr=10.244.0.0/16









#PROBLEMA DE FALTA DE MEMORIA EN VIRTUALBOX

# Detener todas las máquinas virtuales en ejecución (si existe alguna)
echo "Deteniendo todas las máquinas virtuales en ejecución..."
running_vms=$(VBoxManage list runningvms | cut -d " " -f 1)
if [ -n "$running_vms" ]; then
    for vm_name in $running_vms; do
        VBoxManage controlvm "$vm_name" acpipowerbutton
        echo "Máquina virtual $vm_name detenida."
    done
else
    echo "No hay máquinas virtuales en ejecución."
fi

# Esperar un poco para asegurarse de que todas las máquinas virtuales se apaguen
echo "Esperando 5 segundos para que las máquinas virtuales se apaguen correctamente..."
sleep 5

# Asegurarse de que no hay procesos de VirtualBox en ejecución
echo "Verificando procesos de VirtualBox..."
VBoxPID=$(pgrep -f VirtualBox)
if [ -n "$VBoxPID" ]; then
    echo "VirtualBox sigue en ejecución, deteniendo procesos..."
    kill -9 $VBoxPID
    echo "Procesos de VirtualBox detenidos."
else
    echo "No hay procesos de VirtualBox en ejecución."
fi

# Limpiar archivos temporales de VirtualBox (directorios ocultos y logs)
echo "Limpiando archivos temporales de VirtualBox..."
rm -rf ~/.VirtualBox
rm -rf ~/VirtualBox\ VMs/*/Logs/*

# Limpiar cachés del sistema y liberar recursos de memoria
echo "Liberando memoria y limpiando cachés del sistema..."
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

# Reiniciar el servicio de VirtualBox (en sistemas basados en systemd)
echo "Reiniciando servicio de VirtualBox..."
sudo systemctl restart vboxdrv

# Verificar la memoria disponible
echo "Verificando la memoria disponible..."
free -h

# Verificar si la memoria sigue alta y sugerir acciones
available_memory=$(free -h | grep Mem | awk '{print $7}' | sed 's/[^0-9]*//g')
if [ "$available_memory" -lt 8000 ]; then
    echo "La memoria disponible sigue siendo baja, por favor revisa los procesos que están utilizando recursos y considera reiniciar el sistema."
else
    echo "Memoria suficiente disponible."
fi

echo "Proceso completo. Memoria liberada y VirtualBox reiniciado."

