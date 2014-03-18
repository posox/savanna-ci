#!/bin/bash -e

sudo iptables -F
sudo apt-get install xserver-xorg -y
sudo pip install $WORKSPACE

SAVANNA_LOG=/tmp/sahara.log 

SCR_CHECK=$(ps aux | grep screen | grep display)
if [ -n "$SCR_CHECK" ]; then
     screen -S display -X quit
fi

screen -S sahara -X quit

#DETECT_XVFB=$(ps aux | grep Xvfb | grep -v grep)
DETECT_XVFB=$(ps aux | grep X | grep -v grep)
if [ -n "$DETECT_XVFB" ]; then
     sudo killall X
fi

ps aux | grep X

#rm -f /tmp/savanna-server.db
rm -rf /tmp/cache

mysql -usavanna-citest -psavanna-citest -Bse "DROP DATABASE IF EXISTS savanna"
mysql -usavanna-citest -psavanna-citest -Bse "create database savanna"

BUILD_ID=dontKill

#screen -dmS display sudo Xvfb -fp /usr/share/fonts/X11/misc/ :22 -screen 0 1024x768x16
screen -dmS display sudo X

export DISPLAY=:0

cd $HOME
rm -rf sahara

echo "
[DEFAULT]

os_auth_host=172.18.168.42
os_auth_port=5000
os_admin_username=ci-user
os_admin_password=nova
os_admin_tenant_name=ci
use_floating_ips=true
use_neutron=true

plugins=vanilla,hdp,idh

[database]
connection=mysql://savanna-citest:savanna-citest@localhost/savanna?charset=utf8"  > sahara.conf

git clone https://github.com/openstack/sahara
cd sahara
tox -evenv -- sahara-db-manage --config-file $HOME/sahara.conf upgrade head
screen -dmS sahara /bin/bash -c "PYTHONUNBUFFERED=1 tox -evenv -- sahara-api --config-file $HOME/sahara.conf -d --log-file /tmp/sahara.log"

while true
do
        if [ ! -f $SAVANNA_LOG ]; then
                sleep 10
        else
                echo "project is started" && FAILURE=0 && break
        fi
done

sudo service apache2 restart
sleep 20

echo "
[common]
base_url = 'http://127.0.0.1/horizon'
user = 'ci-user'
password = 'nova'
tenant = 'ci'
flavor = 'm1.small'
neutron_management_network = 'private'
floationg_ip_pool = 'public'
keystone_url = 'http://172.18.168.42:5000/v2.0'
await_element = 120
image_name_for_register = 'ubuntu-12.04'
image_name_for_edit = "savanna-itests-ci-vanilla-image"
[vanilla]
skip_plugin_tests = False
skip_edp_test = False
base_image = "savanna-itests-ci-vanilla-image"
[hdp]
skip_plugin_tests = False
hadoop_version = '1.3.2'
" >> $WORKSPACE/saharadashboard/tests/configs/config.conf

cd $WORKSPACE && tox -e uitests
