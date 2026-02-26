# Oracle InstantClient OpenShift Deployment

This repository contains resources to build and deploy an Oracle **Instant Client** image to an OpenShift environment.  
The image bundles the client libraries and tools required for applications running in Kubernetes/OpenShift to connect to Oracle databases.

---

## 🔧 Prerequisites

1. **OpenShift CLI (`oc`)** – authenticated to your cluster.
2. **Docker / Podman** – for building the container locally.
<!-- 3. **Oracle Instant Client ZIP files** – you must download these yourself from [Oracle](https://www.oracle.com/database/technologies/instant-client.html) (accept license terms).
   - e.g. `instantclient-basiclite-linux.x64-21.3.0.0.0.zip`
   - Put them in this repo or reference the location in Dockerfile. -->
3. A project/namespace in OpenShift where you have push rights.

---

## 🏗️ Building the Image

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

## ⚙️ Configuration

- **tnsnames-config.yml** – contains sample TNS entries that your applications can mount or copy into containers.
- **instantclient-app-deployment.yml** – demo workload; change it to deploy real workloads that link against the Instant Client.

---

## 📝 Notes

- The Instant Client is licensed software; ensure compliance when redistributing.
- You can build a multi-arch image or add additional tools (e.g. SQL*Plus) by modifying the Dockerfile.

