echo "$(kubectl get ing --all-namespaces | awk '{print $5, $4}')" | sort -r -u
