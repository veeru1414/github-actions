echo "https://github.com/veeru1414/github-actions/releases/download/$2/mqtest.bar"

echo "Deleting Existing Integration Server..."

oc delete integrationserver -n $1 mq-integration

cat > integrationserver.yaml << EOF
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationServer
metadata:
  name: mq-integration
  labels: {}
  namespace: $1
spec:
  adminServerSecure: true
  barURL: >-
    https://github.com/veeru1414/github-actions/releases/download/$2/mqtest.bar
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




if [ $phaseIS == Ready ]
   then echo Integration Server is ready; 
   exit; 
fi

if [ $phaseIS != Ready ]
   then echo Integration Server is NOT ready; 
   exit 1; 
fi
