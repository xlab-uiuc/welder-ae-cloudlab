#!/bin/bash

#
# Install Ansible
#

sudo apt update
sudo apt -y install software-properties-common pkg-config
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt -y install ansible
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general

#
# Checkout the repository
#

cd /local/repository/

#
# Prepare the CloudLab machine(s) with Ansible
#

cd scripts/ansible/
# By default the user will be the current one (who instantiate the profile and
# create this experiment)
echo 127.0.0.1 > ansible_hosts
# Work around the key authentication
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N "" && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
ansible-playbook -i ansible_hosts configure.yaml
source ~/.bashrc

#
# Set up the anvil repo: Rust toolchain, Verus, and the LOC tooling
#

if [ ! -d ~/anvil ]; then
    git clone --branch sosp26 https://github.com/anvil-verifier/anvil.git ~/anvil
fi
bash ~/anvil/tools/setup-welder-env.sh
pip3 install tabulate

#
# Make cargo and Verus available in future login shells
#

grep -qF '. "$HOME/.cargo/env"' ~/.bashrc || echo '. "$HOME/.cargo/env"' >> ~/.bashrc
grep -qF 'export PATH="$PATH:$HOME/verus"' ~/.bashrc || echo 'export PATH="$PATH:$HOME/verus"' >> ~/.bashrc

newgrp docker