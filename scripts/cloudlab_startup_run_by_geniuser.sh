#!/bin/bash
if [ ! -f /etc/cloudlab/SETUP_SUCCESS ]
then
    experiment_creator=$( geni-get user_urn | rev | cut -d '+' -f -1 | rev )
    sudo su -c "bash /local/repository/scripts/cloudlab_startup_run_by_creator.sh" $experiment_creator &> /tmp/startup_log &&\
        sudo mkdir /etc/cloudlab &&\
        sudo touch /etc/cloudlab/SETUP_SUCCESS
fi
