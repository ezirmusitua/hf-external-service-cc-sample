## Hyperledger Fabric Run Chaincode As External Service Sample

The sample project demostrated how to use chaincode as external service in hyperledger fabric 2.0

## How To Run

Suppose you already in the project directory

First, start the test network and deploy the chaincode

```bash
# go to test-network
pushd test-network

# if you already using sample network in fabric-samples, remember to stop it at first
bash network.sh down
bash network.sh up createChannel
bash network.sh deployAnyCC -n fabcares -l service -v 1

# back to project root
popd
```

if chaincode deployed successfully, you should found the installed *****packageID** in the std out, copy it for following step

Secondly, run the external chaincode service

```bash
# go to fabcar external service chaincode source directory
pushd chaincode/fabcar/external

# edit the chaincode.env file, update the CHAINCODE_ID value to copied packageID in previous step
## vi chaincode.env
## ...
CHAINCODE_ID=<packageID>
## ...
## :wq

# build 
docker build -t hyperledger/fabcar-sample .
docker run -it --rm \
         --name fabcar.org1.example.com \
         --hostname fabcar.org1.example.com \
         --env-file chaincode.env \
         --network=net_test hyperledger/fabcar-sample

```

Finally, init and call the chaincode

Do not stop the running external service container, open another terminal session, run following script

```bash
# go to the test-network directory
pushd /path/to/project/test-network

# call init chaincode
bash network.sh callCC -cc fabcares -fn initLedger -fa '""' -init 1
# call query
bash network.sh callCC -cc fabcares -fn queryAllCars -fa '""'

```

if things all right, at the end you could see the same result as the `bash network.sh deployCC` showed


## Some tips

for build pack scripts, ensure all been mounted to the peer contaienr, 

and the tools and commands using in build pack scrips should ensure installed in peer container,

cause hyperledger fabric images using alpine in 2.0, make sure the tools or commands you need already installed manually

if could using external builder, for example, error log tell the Unknown chaincodeType, try change the PEER_LOGGING_LEVEL to DEBUG,

and search something like `external` in peer container logs
