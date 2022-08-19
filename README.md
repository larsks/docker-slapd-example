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

Once everything has deployed, you can test it by running:

```
kubectl exec -n slapd -it deploy/client -- \
  ldapsearch -H ldap://slapd -D cn=manager,dc=example,dc=com -w secret -x \
  -b ou=users,dc=example,dc=com -s sub
```

Which should return:

```
# extended LDIF
#
# LDAPv3
# base <ou=users,dc=example,dc=com> with scope subtree
# filter: (objectclass=*)
# requesting: ALL
#

# users, example.com
dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
ou: users

# user1, users, example.com
dn: cn=user1,ou=users,dc=example,dc=com
objectClass: organizationalPerson
objectClass: simpleSecurityObject
cn: user1
sn: user1
userPassword:: e1NTSEF9bE5ubjA0OGY1VEZNcWpiL2hXYU1pYlltNUxhdkRGdEs=

# user2, users, example.com
dn: cn=user2,ou=users,dc=example,dc=com
objectClass: organizationalPerson
objectClass: simpleSecurityObject
cn: user2
sn: user2
userPassword:: e1NTSEF9dk5FVW8xTTQyYUc5dzRwMXp3TWtqWTIrN3hVemVPZUY=

# search result
search: 2
result: 0 Success

# numResponses: 4
# numEntries: 3
```
