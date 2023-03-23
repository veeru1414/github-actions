#!/bin/bash

echo "Testing Parameterization $1"

# Create a private key and a self-signed certificate for the queue manager

openssl req -newkey rsa:2048 -nodes -keyout qm1.key -subj "/CN=qm1" -x509 -days 3650 -out qm1.crt

# Create the client key database::

# runmqakm -keydb -create -db app1key.kdb -pw password -type cms -stash

# Add the queue manager public key to the client key database:

#runmqakm -cert -add -db app1key.kdb -label qm1cert -file qm1.crt -format ascii -stashed

# Check. List the database certificates:

#runmqakm -cert -list -db app1key.kdb -stashed

# Create TLS Secret for the Queue Manager

oc create secret tls example-01-qm1-secret -n $1 --key="qm1.key" --cert="qm1.crt"

# Create a config map containing MQSC commands

cat > qm1-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-01-qm1-configmap
data:
  qm1.mqsc: |
    DEFINE QLOCAL('IN')
    DEFINE QLOCAL('OUT')
    DEFINE CHANNEL(IN_OUT) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(OPTIONAL)
    ALTER QMGR CHLAUTH(DISABLED) CONNAUTH('')
    REFRESH SECURITY
EOF

oc apply -n $1 -f qm1-configmap.yaml

# Create the required route for SNI

cat > qm1chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-01-qm1-route
spec:
  host: qm1chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm1-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF

oc apply -n $1 -f qm1chl-route.yaml

# Deploy the queue manager

cat > qm1-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm1
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM1
    mqsc:
    - configMap:
        name: example-01-qm1-configmap
        items:
        - qm1.mqsc
    storage:
      queueManager:
        type: ephemeral
  template:
    pod:
      containers:
        - env:
            - name: MQSNOAUT
              value: 'yes'
          name: qmgr
  version: 9.3.0.0-r2
  web:
    enabled: true
  pki:
    keys:
      - name: example
        secret:
          secretName: example-01-qm1-secret
          items: 
          - tls.key
          - tls.crt
EOF


for i in {1}
do
  phase=`oc get qmgr -n $1 qm1 -o jsonpath="{.status.phase}"`
  if [ "$phase" == "Running" ] ; then break; fi
  echo "Waiting for qm1...$i"
  oc get qmgr -n $1 qm1
  sleep 5
done


oc apply -n $1 -f qm1-qmgr.yaml;


# wait 5 minutes for queue manager to be up and running
# (shouldn't take more than 2 minutes, but just in case)
for i in {1..60}
do
  phase=`oc get qmgr -n $1 qm1 -o jsonpath="{.status.phase}"`
  if [ "$phase" == "Running" ] ; then break; fi
  echo "Waiting for qm1...$i"
  oc get qmgr -n $1 qm1
  sleep 5
done

oc delete integrationserver -n $1 mq-integration

#Create Integration Server

cat > integrationserver.yaml << EOF
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationServer
metadata:
  name: mq-integration
  labels: {}
  namespace: cp4i
spec:
  adminServerSecure: true
  barURL: >-
    https://github.com/veeru1414/github-actions/releases/download/v9.9.4/New.bar
  configurations:
    - mqtest-pp
    - sample-barauth
  createDashboardUsers: true
  designerFlowsOperationMode: disabled
  enableMetrics: true
  license:
    accept: true
    license: L-MSST-58UM6D
    use: CloudPakForIntegrationNonProduction
  pod:
    containers:
      runtime:
        resources:
          limits:
            cpu: 300m
            memory: 368Mi
          requests:
            cpu: 300m
            memory: 368Mi
  replicas: 1
  router:
    timeout: 120s
  service:
    endpointType: http
  version: 12.0-lts
EOF

echo "Deploying Integration Server in $1"
oc apply -n $1 -f integrationserver.yaml


for i in {1..60}
do
  phaseIS=`oc get integrationserver -n cp4i mq-integration -o jsonpath="{.status.phase}"`
  if [ "$phaseIS" == "Ready" ] ; then break; fi
  echo "Waiting for Integration Server...$i"
  oc get integrationserver -n $1 mq-integration
  sleep 5
done

if [ $phase == Running ]
   then echo Queue Manager qm1 is ready; 
   #exit; 
fi

if [ $phase != Running ]
   then echo "*** Queue Manager qm1 is not ready ***"; 
   exit 1; 
fi


if [ $phaseIS == Ready ]
   then echo Integration Server is ready; 
   exit; 
fi

if [ $phaseIS != Ready ]
   then echo Integration Server is NOT ready; 
   exit 1; 
fi


