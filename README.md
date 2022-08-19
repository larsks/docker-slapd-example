# Running slapd in a container

## Deploying in Docker

```
docker run --name slapd --rm -v $PWD/k8s/config:/docker-entrypoint.d ghcr.io/larsks/docker-slapd-example:main
```

You can test things by running:

```
docker exec slapd \
  ldapsearch -H ldap:// -D cn=manager,dc=example,dc=com -w secret -x \
  -b ou=users,dc=example,dc=com -s sub
```

## Deploying in Kubernetes

```
kubectl create ns slapd
kubectl -n slapd apply -k k8s
```

Once everything has deployed, you can test it by running:

```
kubectl exec -n slapd -it deploy/client -- \
  ldapsearch -H ldap://slapd -D cn=manager,dc=example,dc=com -w secret -x \
  -b ou=users,dc=example,dc=com -s sub
```
