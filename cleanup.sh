#!/bin/bash

echo "Deleting queue manager...."
oc delete -n cp4i qmgr qm1

echo "Deleting config map...."
oc delete -n cp4i cm example-01-qm1-configmap


echo "Deleting route...."
oc delete -n cp4i route example-01-qm1-route

echo "Deleting secret...."
oc delete -n cp4i secret example-01-qm1-secret
