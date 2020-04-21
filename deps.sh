#!/usr/bin/bash

echo "Pulling fabric related images ..."

sudo docker pull hyperledger/fabric-peer:2.0.0
sudo docker tag hyperledger/fabric-peer:2.0.0 hyperledger/fabric-peer:latest

sudo docker pull hyperledger/fabric-orderer:2.0.0
sudo docker tag hyperledger/fabric-orderer:2.0.0 hyperledger/fabric-orderer:latest

sudo docker pull hyperledger/fabric-ccenv:2.0.0
sudo docker tag hyperledger/fabric-ccenv:2.0.0 hyperledger/fabric-ccenv:latest

sudo docker pull hyperledger/fabric-baseos:2.0.0
sudo docker tag hyperledger/fabric-baseos:2.0.0 hyperledger/fabric-baseos:latest

sudo docker pull hyperledger/fabric-nodeenv:2.0.0
sudo docker tag hyperledger/fabric-nodeenv:2.0.0 hyperledger/fabric-nodeenv:latest

sudo docker pull hyperledger/fabric-tools:2.0.0
sudo docker tag hyperledger/fabric-tools:2.0.0 hyperledger/fabric-tools:latest

sudo docker pull hyperledger/fabric-ca:1.4.6
sudo docker tag hyperledger/fabric-ca:1.4.6 hyperledger/fabric-ca:latest

sudo docker pull hyperledger/fabric-couchdb:0.4.18
sudo docker tag hyperledger/fabric-couchdb:0.4.18 hyperledger/fabric-couchdb:latest

BIN_URL="https://github.com/hyperledger/fabric/releases/download/v2.0.1/hyperledger-fabric-darwin-amd64-2.0.1.tar.gz"
CA_URL="https://github.com/hyperledger/fabric-ca/releases/download/v1.4.6/hyperledger-fabric-ca-darwin-amd64-1.4.6.tar.gz"
if [[ "$(uname -a)" == *"Linux"* ]];then
  BIN_URL="https://github.com/hyperledger/fabric/releases/download/v2.0.1/hyperledger-fabric-linux-amd64-2.0.1.tar.gz"
  CA_URL="https://github.com/hyperledger/fabric-ca/releases/download/v1.4.6/hyperledger-fabric-ca-linux-amd64-1.4.6.tar.gz"
fi

echo "Download fabric binaries ..."
curl $BIN_URL -Lo fabric.tar.gz
tar xzf fabric.tar.gz
rm fabric.tar.gz


echo "Download ca binaries ..."
curl $CA_URL -Lo ca.tar.gz
tar xzf ca.tar.gz
rm ca.tar.gz

sudo chmod +x **

