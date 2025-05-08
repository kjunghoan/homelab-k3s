# Secrets Management

This repository uses [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to securely store Kubernetes secrets in a public repository.

## How It Works

1. Secrets are created locally as Kubernetes Secret objects
2. The `kubeseal` tool encrypts them using the cluster's public key
3. Only the sealed-secrets controller in the cluster can decrypt them
4. Raw secrets are stored in the `secrets/` directory (gitignored)
5. Sealed secrets are stored in the `sealed-secrets/` directory (committed to git)

## Creating a New Secret

Use the provided script:

```bash
./scripts/secrets/seal-secret.sh secret-name namespace key1=value1 key2=value2
```

Example:
```bash
./scripts/secrets/seal-secret.sh db-credentials default username=admin password=supersecret
```

## Applying Secrets to the Cluster

```bash
kubectl apply -f sealed-secrets/namespace/secret-name.yaml
```

## Retrieving a Secret Value

```bash
kubectl get secret secret-name -n namespace -o jsonpath='{.data.key}' | base64 -d
```

## IMPORTANT

NEVER commit the contents of the `secrets/` directory to git. They contain the raw secret values.
Only commit the `sealed-secrets/` directory, which contains the encrypted secrets.
