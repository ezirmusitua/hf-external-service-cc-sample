CHANNEL_NAME="$1"
CC_NAME="$2"
CC_SRC_LANGUAGE="$3"
CC_SRC_PATH="$4"
VERSION="$5"
DELAY="$6"
MAX_RETRY="$7"
VERBOSE="$8"
: ${CHANNEL_NAME:="mychannel"}
: ${CC_NAME:=""}
: ${CC_SRC_LANGUAGE:="golang"}
: ${CC_SRC_PATH:=""}
: ${VERSION:="1"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}

if [ "$CC_NAME" = "" ]; then
  echo "For deploying chaincode, you must provide chaincode name for constructing package name and label"
  exit 1
fi

if [ "$CC_SRC_PATH" = "" ]; then
  echo "For deploying chaincode, you must provide chaincode source path"
  exit 1
fi

CC_SRC_LANGUAGE=`echo "$CC_SRC_LANGUAGE" | tr [:upper:] [:lower:]`


FABRIC_CFG_PATH=$PWD/../config/

if [ "$CC_SRC_LANGUAGE" = "go" -o "$CC_SRC_LANGUAGE" = "golang" ] ; then
  CC_RUNTIME_LANGUAGE=golang

  echo Vendoring Go dependencies ...
  pushd $CC_SRC_PATH
  GO111MODULE=on go mod vendor
  popd
  echo Finished vendoring Go dependencies

elif [ "$CC_SRC_LANGUAGE" = "javascript" ]; then
  CC_RUNTIME_LANGUAGE=node # chaincode runtime language is node.js

elif [ "$CC_SRC_LANGUAGE" = "java" ]; then
  CC_RUNTIME_LANGUAGE=java

  echo Compiling Java code ...
  pushd $CC_SRC_PATH
  ./gradlew installDist
  popd
  echo Finished compiling Java code

elif [ "$CC_SRC_LANGUAGE" = "typescript" ]; then
  CC_RUNTIME_LANGUAGE=node # chaincode runtime language is node.js

  echo Compiling TypeScript code into JavaScript ...
  pushd $CC_SRC_PATH
  npm install
  npm run build
  popd
  echo Finished compiling TypeScript code into JavaScript

elif [ "$CC_SRC_LANGUAGE" = "service" ]; then
  CC_RUNTIME_LANGUAGE=service

  echo "For deploying with external service builder and launcher, "
  echo "ensure the builder/launcher environment has prepare properly, "
  echo "and the chaincode source code directory must supply connection.json and metadata.json"
  echo "must supply too. "
  if [ ! -f $CC_SRC_PATH/connection.json ]; then
    echo "connection.json not found"
    exit 1
  fi
  if [ ! -f $CC_SRC_PATH/metadata.json ]; then
    echo "metadata.json not found"
    exit 1
  fi

elif [ "$CC_SRC_LANGUAGE" = "external" ]; then
  CC_RUNTIME_LANGUAGE=external

  echo "For deploying with external builder and launcher, "
  echo "ensure the builder/launcher environment has prepare properly"
  echo "and you should package the source code properly manually"

else
  echo The chaincode language ${CC_SRC_LANGUAGE} is not supported by this script
  echo Supported chaincode languages are: go, java, javascript, and typescript
  exit 1
  fi

# import utils
. scripts/envVar.sh


packageChaincode() {
  ORG=$1
  setGlobals $ORG
  if [ "$CC_SRC_LANGUAGE" = "service" ]; then
    pushd $CC_SRC_PATH
    set -x
    tar czf code.tar.gz connection.json
    tar czf ${CC_NAME}.tgz code.tar.gz metadata.json
    set +x
    popd

  elif [ "$CC_SRC_LANGUAGE" = "external" ]; then
    if [ ! -f "$CC_SRC_PATH/${CC_NAME}.tgz" ]; then
      echo "External package not found"
      exit 1
    fi
  else
    set -x
    peer lifecycle chaincode package ${CC_SRC_PATH}/${CC_NAME}.tgz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${VERSION} >&log.txt
    res=$?
    set +x
    cat log.txt
    verifyResult $res "Chaincode packaging on peer0.org${ORG} has failed"
  fi
  echo "===================== Chaincode is packaged on peer0.org${ORG} ===================== "
  echo
}

# installChaincode PEER ORG
installChaincode() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode install ${CC_SRC_PATH}/${CC_NAME}.tgz >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode installation on peer0.org${ORG} has failed"
  echo "===================== Chaincode is installed on peer0.org${ORG} ===================== "
  echo
}

# queryInstalled PEER ORG
queryInstalled() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode queryinstalled >&log.txt
  res=$?
  set +x
  cat log.txt
  PACKAGE_ID=$(sed -n "/${CC_NAME}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
  verifyResult $res "Query installed on peer0.org${ORG} has failed"
  echo PackageID is ${PACKAGE_ID}
  echo "===================== Query installed successful on peer0.org${ORG} on channel ===================== "
  echo
}

# approveForMyOrg VERSION PEER ORG
approveForMyOrg() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls $CORE_PEER_TLS_ENABLED \
    --cafile $ORDERER_CA \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version ${VERSION} \
    --init-required \
    --package-id ${PACKAGE_ID} \
    --sequence ${VERSION} >&log.txt
  set +x
  cat log.txt
  verifyResult $res "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME' ===================== "
  echo
}

# checkCommitReadiness VERSION PEER ORG
checkCommitReadiness() {
  ORG=$1
  shift 1
  setGlobals $ORG
  echo "===================== Checking the commit readiness of the chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'... ===================== "
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    echo "Attempting to check the commit readiness of the chaincode definition on peer0.org${ORG} secs"
    set -x
    peer lifecycle chaincode checkcommitreadiness \
      --channelID $CHANNEL_NAME \
      --name $CC_NAME \
      --version ${VERSION} \
      --sequence ${VERSION} \
      --output json \
      --init-required >&log.txt
    res=$?
    set +x
    let rc=0
    for var in "$@"
    do
      grep "$var" log.txt &>/dev/null || let rc=1
    done
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    echo "===================== Checking the commit readiness of the chaincode definition successful on peer0.org${ORG} on channel '$CHANNEL_NAME' ===================== "
  else
    echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Check commit readiness result on peer0.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

# commitChaincodeDefinition VERSION PEER ORG (PEER ORG)...
commitChaincodeDefinition() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  set -x
  peer lifecycle chaincode commit \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls $CORE_PEER_TLS_ENABLED \
    --cafile $ORDERER_CA \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME $PEER_CONN_PARMS \
    --version ${VERSION} \
    --sequence ${VERSION} \
    --init-required >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  echo "===================== Chaincode definition committed on channel '$CHANNEL_NAME' ===================== "
  echo
}

# queryCommitted ORG
queryCommitted() {
  ORG=$1
  setGlobals $ORG
  EXPECTED_RESULT="Version: ${VERSION}, Sequence: ${VERSION}, Endorsement Plugin: escc, Validation Plugin: vscc"
  echo "===================== Querying chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'... ===================== "
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    echo "Attempting to Query committed status on peer0.org${ORG}, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode querycommitted \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME >&log.txt

    res=$?
    set +x
    test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: [0-9], Sequence: [0-9], Endorsement Plugin: escc, Validation Plugin: vscc')
    test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
    COUNTER=$(expr $COUNTER + 1)
  done
  echo
  cat log.txt
  if test $rc -eq 0; then
    echo "===================== Query chaincode definition successful on peer0.org${ORG} on channel '$CHANNEL_NAME' ===================== "
    echo
  else
    echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Query chaincode definition result on peer0.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

## at first we package the chaincode
packageChaincode 1

## Install chaincode on peer0.org1 and peer0.org2
echo "Installing chaincode on peer0.org1..."
installChaincode 1
echo "Install chaincode on peer0.org2..."
installChaincode 2

## query whether the chaincode is installed
queryInstalled 1
sleep 2
queryInstalled 2
sleep 2

## approve the definition
approveForMyOrg 1
sleep 2
approveForMyOrg 2
sleep 2

## check whether the chaincode definition is ready to be committed
## expect them both to have approved
checkCommitReadiness 1 "\"Org1MSP\": true" "\"Org2MSP\": true"
checkCommitReadiness 2 "\"Org1MSP\": true" "\"Org2MSP\": true"

## now that we know for sure both orgs have approved, commit the definition
commitChaincodeDefinition 1 2

## query on both orgs to see that the definition committed successfully
queryCommitted 1
queryCommitted 2

rm log.txt

exit 0
