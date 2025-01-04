#!/bin/sh
#Kubectl in file because ansible struggle to handle multiple quotes
kubectl -n longhorn-system patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag