#!/bin/bash -e

sudo pip install $WORKSPACE


SAVANNA_LOG=/tmp/savanna.log 

SCR_CHECK=$(ps aux | grep screen | grep display)
if [ -n "$SCR_CHECK" ]; then
     screen -S display -X quit
fi

SCR_CHECK=$(ps aux | grep screen | grep savanna)
if [ -n "$SCR_CHECK" ]; then
     screen -S savanna -X quit
fi

DETECT_XVFB=$(ps aux | grep Xvfb | grep -v grep)
if [ -n "$DETECT_XVFB" ]; then
     sudo killall Xvfb
fi

ps aux | grep Xvfb

rm -f /tmp/savanna-server.db
rm -rf /tmp/cache

BUILD_ID=dontKill

screen -dmS display sudo Xvfb -fp /usr/share/fonts/X11/misc/ :22 -screen 0 1024x768x16

export DISPLAY=:22

cd /home/ubuntu
rm -rf savanna-venv
virtualenv savanna-venv
savanna-venv/bin/pip install -e git://github.com/openstack/savanna.git#egg=savanna
screen -dmS savanna /bin/bash -c "savanna-venv/bin/python savanna-venv/bin/savanna-api --config-file /home/ubuntu/savanna.conf -d --log-file /tmp/savanna.log"

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
image_name_for_register = 'ubuntu-12.04-latest'
image_name_for_edit = "savanna-itests-ci-vanilla-image"
[vanilla]
skip_plugin_tests = False
skip_edp_test = False
base_image = "savanna-itests-ci-vanilla-image"
[hdp]
skip_plugin_tests = False
hadoop_version = '1.3.2'
" >> $WORKSPACE/savannadashboard/tests/configs/config.conf

cd $WORKSPACE && tox -e uitests
