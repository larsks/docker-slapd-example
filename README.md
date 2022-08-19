# Running slapd in a container

## Deploying in Docker

```
docker run --rm -v $PWD/example.com:/docker-entrypoint.d ghcr.io/larsks/docker-slapd-example:main
```

## Deploying in Kubernetes

```
kubectl create ns slapd
kubectl -n slapd apply -k k8s
```
