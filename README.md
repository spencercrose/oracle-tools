# Oracle InstantClient OpenShift Deployment

This repository contains resources to build and deploy an Oracle **Instant Client** image to an OpenShift environment.  
The image bundles the client libraries and tools required for applications running in Kubernetes/OpenShift to connect to Oracle databases.

---

## 🔧 Prerequisites

1. **OpenShift CLI (`oc`)** – authenticated to your cluster.
2. **(OPTIONAL) Docker / Podman** – for building the container locally.
<!-- 3. **Oracle Instant Client ZIP files** – you must download these yourself from [Oracle](https://www.oracle.com/database/technologies/instant-client.html) (accept license terms).
   - e.g. `instantclient-basiclite-linux.x64-21.3.0.0.0.zip`
   - Put them in this repo or reference the location in Dockerfile. -->
3. A project/namespace in OpenShift where you have push rights.

---

## 🏗️ (OPTIONAL) Building the Image

# NOTE: The default Instant Client container image is available on GHCR.

```bash
# from repo root
docker build -t myregistry.example.com/instantclient:latest .
# or use podman:
podman build -t myregistry.example.com/instantclient:latest .
```

> The `Dockerfile` bundles the Instant Client files and sets necessary environment variables.

Push the image to your registry:

```bash
docker push myregistry.example.com/instantclient:latest
```

---

## 🚀 Deploying to OpenShift

This repo includes `instantclient-app-deployment.yml`, a manifest that creates a Deployment and Service for testing or demonstration.

1. **Edit the YAML**:
   - Replace the image reference with your registry (default: `image: ghcr.io/spencercrose/oracle-tools:latest`).
   - Replace the TNS configuration for your Oracle database connection.
   ```yaml
   # Sample tnsnames.ora content for Oracle Instant Client
    # Replace with your actual database connection details
    ORCLPDB1 =
      (DESCRIPTION =
        (ADDRESS = (PROTOCOL = TCP)(HOST = your-db-host)(PORT = 1521))
        (CONNECT_DATA =
          (SERVER = DEDICATED)
          (SERVICE_NAME = orclpdb1)
        )
      )
    ```
   - Adjust resource limits and environment variables as needed.

2. **Apply the manifest**:

```bash
oc project my-app-namespace
oc apply -f tnsnames-config.yml
oc apply -f instantclient-app-deployment.yml
```

3. **Verify**:

```bash
oc get pods -l app=instantclient
oc logs deployment/instantclient
```

The sample deployment runs a simple container that may print the Oracle version or wait for connections; modify it for your application logic.


---

## 🧾 Accessing SQL*Plus

The Instant Client image includes **SQL\*Plus**, allowing you to run SQL commands directly inside a container.

1. **Get a shell in a pod**:

```bash
# replace <pod> with the name from oc get pods
oc rsh <pod>
```

2. **Authenticate with the database** using a TNS entry from the mounted `tnsnames.ora` or a connection string:

```bash
# example using TNS name defined in tnsnames-config.yml
echo "password" | sqlplus username@ORCLPDB1

# or using EZCONNECT
sqlplus username/password@//your-db-host:1521/orclpdb1
```

3. **Typical SQL*Plus session**:

```
SQL> SELECT sysdate FROM dual;
SQL> EXIT;
```

> If your project requires interactive use, ensure the pod runs with `stdin: true` and `tty: true` in the deployment spec.

---

## ⚙️ Configuration (TNS)

- **tnsnames-config.yml** – contains sample TNS entries that your applications can mount or copy into containers.
- **instantclient-app-deployment.yml** – demo workload; change it to deploy real workloads that link against the Instant Client.

---

## ⚙️ Configuration (mTLS)

Setting up mTLS on OpenShift adds a layer of complexity because you have to handle the **Oracle Wallet** files securely. Since wallets are binary files (`cwallet.sso`), you shouldn't put them in a ConfigMap (which is for UTF-8 text). Instead, you should use a **Secret**.

Here is how to modify your YAML and environment in OpenShift:

---

## 1. Create the Secret for your Wallet

First, upload your wallet files (usually `cwallet.sso`, `ewallet.p12`) as an OpenShift Secret. Run this from your local machine where the wallet files are:

```bash
oc create secret generic oracle-wallet-secret \
  --from-file=./cwallet.sso \
  --from-file=./ewallet.p12

```

---

## 2. Updated Deployment YAML

You need to mount the new Secret and set the `TNS_ADMIN` environment variable so the Instant Client knows where to look for both the configuration and the keys.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: instantclient-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: instantclient-app
  template:
    metadata:
      labels:
        app: instantclient-app
    spec:
      containers:
        - name: oracle-client-app
          image: ghcr.io/spencercrose/oracle-tools:latest
          env:
            # Tell Oracle where to find tnsnames.ora AND sqlnet.ora
            - name: TNS_ADMIN
              value: "/opt/oracle/network/admin"
          volumeMounts:
            # Mount tnsnames.ora and sqlnet.ora here
            - name: tns-config-volume
              mountPath: /opt/oracle/network/admin/tnsnames.ora
              subPath: tnsnames.ora
            - name: sqlnet-config-volume
              mountPath: /opt/oracle/network/admin/sqlnet.ora
              subPath: sqlnet.ora
            # Mount the binary wallet files here
            - name: wallet-volume
              mountPath: /opt/oracle/wallet
              readOnly: true
          command: ["/bin/bash", "-c", "sleep infinity"]
      volumes:
        - name: tns-config-volume
          configMap:
            name: tnsnames-config
        - name: sqlnet-config-volume
          configMap:
            name: sqlnet-config
        - name: wallet-volume
          secret:
            secretName: oracle-wallet-secret

```

---

## 3. Configure `sqlnet.ora` (The "Glue")

You must create a second ConfigMap named `sqlnet-config` that tells the client to look in `/opt/oracle/wallet` for the mTLS certificates.

**Note the Directory path below matches the `mountPath` of your secret.**

```yaml
# sqlnet.ora content inside your ConfigMap
WALLET_LOCATION =
  (SOURCE =
    (METHOD = File)
    (METHOD_DATA =
      (DIRECTORY = /opt/oracle/wallet)
    )
  )

SSL_CLIENT_AUTHENTICATION = TRUE
SSL_SERVER_DN_MATCH = YES

```

---

## 4. Troubleshooting the "Target Host" on OpenShift

If you still see **ORA-12545** after this setup:

1. **Egress Network Policies:** OpenShift often restricts outgoing traffic. Ensure there isn't an `EgressNetworkPolicy` blocking your pod from hitting the database IP/Port (1522/2484).
2. **FQDN Resolution:** Inside a container, `database-server` might not resolve. Use the Full Qualified Domain Name (e.g., `db-server.corp.internal`).
3. **The "Sticky" TNS_ADMIN:** If your `tnsnames.ora` uses a hostname that resolves to a Load Balancer, the Load Balancer must be configured for **SSL Passthrough**. If the LB tries to terminate the SSL, the mTLS handshake will fail because the LB doesn't have your client certificate.

### Quick Test Command

Once the pod is running, exec into it and try a direct reachability test:

```bash
oc exec -it deployment/instantclient-app -- curl -v telnet://<db-hostname>:1522

```

## 📝 Notes

- The Instant Client is licensed software; ensure compliance when redistributing.
