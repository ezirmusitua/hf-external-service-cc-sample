CHANNEL_NAME="$1"
CC_NAME="$2"
FN_NAME="$3"
FN_ARGS="$4"
IS_INIT="$5"
: ${CHANNEL_NAME:="mychannel"}
: ${CC_NAME:=""}
: ${FN_NAME:=""}
: ${FN_ARGS:="\"\""}
: ${IS_INIT:=0}

if [ "$CC_NAME" = "" ]; then
  echo "Chaincode name is necessary"
  echo
  exit 1
fi

if [ "$FN_NAME" = "" ]; then
  echo "Chaincode function name is necessary"
  echo
  exit 1
fi

FABRIC_CFG_PATH=$PWD/../config/

# import
. scripts/envVar.sh

invokeFn() {

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  if [ $IS_INIT -eq 0 ]; then
    ORG=$1
    setGlobals $ORG
    set -x
    peer chaincode invoke \
      -o localhost:7050 \
      --ordererTLSHostnameOverride orderer.example.com \
      --tls $CORE_PEER_TLS_ENABLED \
      --cafile $ORDERER_CA \
      -C $CHANNEL_NAME \
      -n $CC_NAME \
      -c '{"function":"'${FN_NAME}'","Args":['${FN_ARGS}']}' >&log.txt

    set +x

  else

    parsePeerConnectionParameters $@
    res=$?
    verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "
    set -x

    peer chaincode invoke \
      -o localhost:7050 \
      --ordererTLSHostnameOverride orderer.example.com \
      --tls $CORE_PEER_TLS_ENABLED \
      --cafile $ORDERER_CA \
      -C $CHANNEL_NAME \
      -n $CC_NAME $PEER_CONN_PARMS \
      --isInit \
      -c '{"function":"'${FN_NAME}'","Args":[]}' >&log.txt

    set +x

  fi
  res=$?
  cat log.txt
  verifyResult $res "Invoke execution on $PEERS failed "
  echo "===================== Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME' ===================== "
  echo
}

echo $IS_INIT
if [ $IS_INIT -eq 0 ]; then
  invokeFn 1
else
  invokeFn 1 2
fi

rm log.txt

