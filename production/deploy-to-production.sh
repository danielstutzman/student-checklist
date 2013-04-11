#!/bin/bash -x
cd `dirname $0`
git push
ORIGINAL_DIR=`pwd`
cd ../../ansible
source hacking/env-setup
ansible-playbook -v $ORIGINAL_DIR/deploy-to-production.yml -i $ORIGINAL_DIR/hosts --private-key=~/.ec2/gsg-keypair
