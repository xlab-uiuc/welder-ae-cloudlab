#!/bin/bash

#
# Install Ansible
#

sudo apt update
sudo apt -y install software-properties-common pkg-config libssl-dev
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
# Bake the setup-time images (controllers, reference operator, metrics-server)
# into the kind node image, so the per-trial cluster restarts don't re-pull
# them.  Workload images (pause, rabbitmq) are deliberately NOT preloaded:
# their pull is part of the measured end-to-end window.
#

# Must match the "kubernetes_version" pinned in acto's data/*/config.json
KIND_NODE_IMAGE="kindest/node:v1.30.0"
ACTO_DIR="$HOME/workdir/acto"

if ! sudo docker run --rm --entrypoint ls "$KIND_NODE_IMAGE" /kind/welder-images-preloaded >/dev/null 2>&1; then
    PRELOAD_IMAGES="$(
        grep -rhoE 'image: *[a-zA-Z0-9./:@_-]+' \
            "$ACTO_DIR/data/vdeployment-controller/v0/deploy_remote.yaml" \
            "$ACTO_DIR/data/anvil-rabbitmq-controller/deploy_remote.yaml" \
            "$ACTO_DIR/data/anvil-rabbitmq-controller/deploy_remote_sts_only.yaml" \
            "$ACTO_DIR/data/rabbitmq-operator/v2.5.0/operator.yaml" \
            "$ACTO_DIR/data/metrics-server.yaml" \
            2>/dev/null | sed 's/image: *//' | sort -u
    )"
    echo "Preloading images into $KIND_NODE_IMAGE:"
    echo "$PRELOAD_IMAGES"

    sudo docker pull "$KIND_NODE_IMAGE"

    # Pull the images into a throwaway node container's containerd store and
    # commit it back over the same tag (no /var volume here, unlike real kind
    # nodes, so the image store survives docker commit).
    sudo docker rm -f welder-kind-preload >/dev/null 2>&1 || true
    sudo docker run -d --name welder-kind-preload --privileged \
        --entrypoint sleep "$KIND_NODE_IMAGE" infinity
    sudo docker exec welder-kind-preload bash -c \
        'containerd >/var/log/containerd-preload.log 2>&1 & for i in $(seq 30); do ctr version >/dev/null 2>&1 && exit 0; sleep 1; done; echo "containerd did not start" >&2; exit 1'
    preload_ok=1
    for img in $PRELOAD_IMAGES; do
        # ctr needs fully-qualified references
        case "$img" in
            localhost*/*) ref="$img" ;;
            *.*/*) ref="$img" ;;
            */*) ref="docker.io/$img" ;;
            *) ref="docker.io/library/$img" ;;
        esac
        # Pull with unpack; fall back to content-only fetch (unpacked lazily
        # at first use) for layers that cannot unpack on nested overlayfs.
        if ! sudo docker exec welder-kind-preload ctr -n k8s.io images pull "$ref" >/dev/null 2>&1 &&
           ! sudo docker exec welder-kind-preload ctr -n k8s.io content fetch "$ref" >/dev/null; then
            echo "Failed to preload $ref into the kind node image" >&2
            preload_ok=0
            break
        fi
    done
    if [ "$preload_ok" = 1 ]; then
        sudo docker exec welder-kind-preload bash -c \
            'touch /kind/welder-images-preloaded; pkill containerd; sleep 2'
        sudo docker commit \
            --change 'ENTRYPOINT ["/usr/local/bin/entrypoint","/sbin/init"]' \
            welder-kind-preload "$KIND_NODE_IMAGE"
    else
        echo "Skipping kind node image commit; clusters will pull images over the network" >&2
    fi
    sudo docker rm -f welder-kind-preload
fi

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