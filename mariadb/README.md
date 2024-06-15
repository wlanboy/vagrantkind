# Install mariadb

## create namespace
```
kubectl create namespace database
```

## Create configuration and storage
```
kubectl create -f storage.yaml -n database

kubectl create configmap mariadb-config --from-file=my.cnf -n database
kubectl create secret generic mariadb-root-password --from-literal=password=secret -n database
kubectl create secret generic mariadb-user --from-literal=username=user --from-literal=password=pass -n database
```

## create instance
```
kubectl create -f deployment.yaml -n database
```

## expose instance with service
```
kubectl create -f service.yaml -n database
```

## get service information
```
kubectl get svc mariadb -n database
NAME      TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)          AGE
mariadb   LoadBalancer   10.96.60.2   172.18.0.101   3306:32435/TCP   29s
```

## connect to postgresql
```
kubectl exec -it mariadb-deployment-7969d49cb5-jk6tp -n database -- /bin/sh

$ mariadb --host 172.18.0.101 --port 3306 --user user --password
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 3
Server version: 11.4.2-MariaDB-ubu2404 mariadb.org binary distribution

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> 
```

## delete everything
```
kubectl delete service mariadb -n database
kubectl delete deployment mariadb-deployment -n database
kubectl delete configmap mariadb-config -n database
kubectl delete secret mariadb-root-password -n database
kubectl delete secret mariadb-user -n database
kubectl delete persistentvolumeclaim mariadb-pvc -n database
kubectl delete persistentvolume mariadb-pv -n database
kubectl get all -n database
```
