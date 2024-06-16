# Install mariadb replica cluster

## create namespace
```
kubectl create namespace database-statefull
```

## Create configuration and storage
```
kubectl apply -f configurations.yaml -n database-statefull
kubectl apply -f secrets.yaml -n database-statefull
kubectl apply -f service.yaml -n database-statefull
```

## create statefullset
```
kubectl apply -f statefullset.yaml -n database-statefull
```

## get service information
```
kubectl get sts mariadb-statefullset -n database-statefull -o wide
NAME                   READY   AGE   CONTAINERS   IMAGES
mariadb-statefullset   2/2     71s   mariadb      mariadb:11.4

kubectl get pods -n database-statefull -o wide
NAME                     READY   STATUS    RESTARTS   AGE     IP           NODE          NOMINATED NODE   READINESS GATES
mariadb-statefullset-0   1/1     Running   0          3m15s   10.244.1.6   kind-worker   <none>           <none>
mariadb-statefullset-1   1/1     Running   0          2m51s   10.244.1.8   kind-worker   <none>           <none>
```

## scale
```
kubectl scale sts mariadb-statefullset -n database-statefull --replicas=3

kubectl get pods -n database-statefull -o wide
NAME                     READY   STATUS    RESTARTS   AGE     IP            NODE          NOMINATED NODE   READINESS GATES
mariadb-statefullset-0   1/1     Running   0          7m3s    10.244.1.6    kind-worker   <none>           <none>
mariadb-statefullset-1   1/1     Running   0          6m39s   10.244.1.8    kind-worker   <none>           <none>
mariadb-statefullset-2   1/1     Running   0          9s      10.244.1.10   kind-worker   <none>           <none>
```

## connect to postgresql
```
kubectl exec -it mariadb-statefullset-0 -n database-statefull -- mariadb -uroot -psecret

Defaulted container "mariadb" out of: mariadb, init-mariadb (init)
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 4
Server version: 11.4.2-MariaDB-ubu2404-log mariadb.org binary distribution

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> 
create database test;
show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| primary_db         |
| sys                |
| test                |
+--------------------+
6 rows in set (0.001 sec)

kubectl exec -it mariadb-statefullset-1 -n database-statefull -- mariadb -uroot -psecret

Defaulted container "mariadb" out of: mariadb, init-mariadb (init)
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 4
Server version: 11.4.2-MariaDB-ubu2404-log mariadb.org binary distribution

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| primary_db         |
| sys                |
| test               |
+--------------------+
6 rows in set (0.001 sec)
```

## delete everything
```
kubectl delete service mariadb-service -n database-statefull
kubectl delete sts mariadb-statefullset -n database-statefull
kubectl delete configmap mariadb-configmap -n database-statefull
kubectl delete secret mariadb-secret -n database-statefull
kubectl get all -n database-statefull
kubectl delete namespace database-statefull
```
