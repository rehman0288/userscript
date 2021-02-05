#!/bin/bash
cwd=`pwd`
#Creating NameSpace
echo "please type namespace"
read namespace
kubectl create namespace $namespace

#Create User
echo "please type username"
read username
useradd $username

#setting up password
echo "redhat" | passwd --stdin $username
echo "------------------------------Create Private Key----------------------------------------------"
echo "Please Type Key Name with extension .key"
read privatekey
openssl genrsa -out $privatekey 2048

echo "-----------------------Create Certificate Signing Requests------------------------------------"
echo "please type certificate signing request name with extension .csr"
read csr
openssl req -new -key $privatekey -out $csr -subj "/CN=$username/O=$namespace"

echo "-------------------------Copying ca.crt and ca.key in current location-------------------------"
cp -rvf /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/ca.key $cwd/

echo "---------------------------------- To Sign Key ------------------------------------------"
echo "please type certificate name with extension .crt"
read crt
openssl x509 -req -in $csr -CA ca.crt -CAkey ca.key -CAcreateserial -out $crt -days 365

echo "---------------------------------Creating kubeconfig File--------------------------------"
clustername=`kubectl config view | grep cluster | tail -n 1 | awk '{print $2}'`
myipaddress=`ifconfig | grep -A 1 ens192 | tail -1 | awk '{print $2}'`

kubectl --kubeconfig kube.kubeconfig config set-cluster $clustername --server https://$myipaddress:6443 --certificate-authority=ca.crt

echo "------------------------------------ Add user in Kube Config File-----------------------------------"
kubectl --kubeconfig kube.kubeconfig config set-credentials $username --client-certificate $cwd/$crt --client-key $cwd/$privatekey
kubectl --kubeconfig kube.kubeconfig config set-context $username-kubernetes --cluster $clustername --namespace $namespace --user $username
sed -i "/current-context/c current-context: $username-kubernetes" kube.kubeconfig
mv kube.kubeconfig config


echo "-------------------- Copying Files --------------------------"
mkdir /home/$username/.kube
cp -rvf $cwd/* /home/$username/.kube/
chown -R $username:$username /home/$username/.kube
