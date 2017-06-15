# install all-the-things on a bare ubuntu 16.04

# install docker
sudo apt-get update && sudo apt-get ugrade -y

# set autoupdating
sudo apt install unattended-upgrades

sudo dpkg-reconfigure unattended-upgrades
# you may want to reboot at this point
sudo apt-get -y install \
  apt-transport-https \
  ca-certificates \
  curl

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"

sudo apt-get update

sudo apt-get -y install docker-ce

sudo usermod -a -G docker $USER

sudo bash -c "echo overlay >> /etc/modprobe"
sudo bash -c "echo xt_ipvs >> /etc/modprobe"

# load as we don't want to reboot
sudo modprobe overlay
sudo modprobe xt_ipvs

# configure lvm
sudo systemctl stop docker
sudo apt-get install thin-provisioning-tools lvm2 -y

sudo pvcreate /dev/sdc
sudo vgcreate docker /dev/sdc
sudo lvcreate --wipesignatures y -n thinpool docker -l 95%VG
sudo lvcreate --wipesignatures y -n thinpoolmeta docker -l 1%VG

sudo lvconvert -y \
--zero n \
-c 512K \
--thinpool docker/thinpool \
--poolmetadata docker/thinpoolmeta

sudo mkdir -p /etc/lvm/profile

sudo bash -c " echo $' \
activation {\n \
  thin_pool_autoextend_threshold=80\n \
  thin_pool_autoextend_percent=20\n \
}\n' \
 > /etc/lvm/profile/docker-thinpool.profile"

 sudo lvchange --metadataprofile docker-thinpool docker/thinpool
 sudo lvs -o+seg_monitor

sudo mkdir /var/lib/docker.bk
sudo mv /var/lib/docker/* /var/lib/docker.bk

sudo bash -c " echo $' \
{\n \
    \"storage-driver\": \"devicemapper\",\n \
    \"storage-opts\": [\n \
        \"dm.thinpooldev=/dev/mapper/docker-thinpool\",\n \
        \"dm.use_deferred_removal=true\",\n \
        \"dm.use_deferred_deletion=true\"\n \
    ],\n \
    \"dns\": [\n \
        \"<docker_gwbridge_ip>\",\n \
        \"8.8.8.8\",\n \
        \"10.0.0.2\"\n \
    ]\n    
}' \
> /etc/docker/daemon.json"

rm -rf /var/lib/docker.bk

export BRIDGE_IP=`ifconfig docker_gwbridge 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`

sudo sed -i -- 's/<docker_gwbridge_ip>/'"$BRIDGE_IP"'/g' /etc/docker/daemon.json


sudo apt-get install golang -y

sudo service docker start
docker swarm init


sudo bash -c " echo $' \
net.ipv4.neigh.default.gc_thresh3 = 8192\n \
net.ipv4.neigh.default.gc_thresh2 = 8192\n \
net.ipv4.neigh.default.gc_thresh1 = 4096\n \
fs.inotify.max_user_instances = 10000\n \
net.ipv4.tcp_tw_recycle = 1\n \
net.netfilter.nf_conntrack_tcp_timeout_established = 600\n \
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 1'\
>> /etc/sysctl.conf"

sudo sysctl -p

docker pull franela/dind:overlay2
docker pull franela/dind

docker run -d \
        -e DIND_IMAGE=franela/dind:overlay2 \
        -e GOOGLE_RECAPTCHA_DISABLED=true \
        -e MAX_PROCESSES=10000 \
        -e EXPIRY=10h \
        --name pwd \
        -p 80:3000 \
        -p 443:3001 \
        -p 53:53/udp \
        -p 53:53/tcp \
        -v /var/run/docker.sock:/var/run/docker.sock -v sessions:/app/pwd/ \
        --restart always \
        franela/play-with-docker:latest ./play-with-docker --name pwd --cname host1 --save ./pwd/sessions

export GOPATH=~/.go



git clone https://github.com/play-with-docker/play-with-docker
cd play-with-docker
go get -v -d -t ./...

sudo apt-get install docker-compose -y

docker-compose up



