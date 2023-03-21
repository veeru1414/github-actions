#!/bin/bash

echo "Deleting queue manager...."
oc delete -n $1 qmgr qm1

echo "Deleting config map...."
oc delete -n $1 cm example-01-qm1-configmap


echo "Deleting route...."
oc delete -n $1 route example-01-qm1-route

echo "Deleting secret...."
oc delete -n $1 secret example-01-qm1-secret
