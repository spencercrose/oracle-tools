# Dockerfile for Oracle Instant Client

# Use the official Oracle Instant Client image as the base
FROM container-registry.oracle.com/database/instantclient:latest

# Create a non-root user and group.
# OpenShift will override the UID/GID at runtime with an arbitrary one,
# but it's good practice to define a non-root user in the image.
# The container will run as the primary GID assigned by OpenShift,
# so we ensure group-writeable permissions for necessary directories.
ARG APP_USER=oracle
ARG APP_GROUP=oracle
ARG APP_UID=1001
ARG APP_GID=1001

# --- Install network utilities using yum ---
RUN yum -y install iputils telnet curl traceroute && \
    yum clean all && \
    rm -rf /var/cache/yum


RUN groupadd -g ${APP_GID} ${APP_GROUP} \
    && useradd -u ${APP_UID} -g ${APP_GROUP} -m -s /bin/bash ${APP_USER}

# Define environment variables for Oracle Instant Client
# These paths are typical for the slim image, verify if your base image differs.
ENV ORACLE_HOME=/usr/lib/oracle/12.2/client64
ENV LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/lib
ENV PATH=$ORACLE_HOME/bin:$PATH

# Define a standard TNS_ADMIN location. This directory will hold tnsnames.ora.
# It must be writable by the user OpenShift assigns at runtime.
ENV TNS_ADMIN=/opt/oracle/tns_admin

# Create the TNS_ADMIN directory and ensure it's writable by the application user.
# The chmod g+rwX is crucial for OpenShift's arbitrary group ID.
RUN mkdir -p ${TNS_ADMIN} \
    && chown -R ${APP_USER}:${APP_GROUP} ${TNS_ADMIN} \
    && chmod -R ug+rwX ${TNS_ADMIN} \
    && chmod -R o+rX ${TNS_ADMIN} # Optional: Allow others to read

# IMPORTANT: The Oracle Instant Client installation directory (/usr/lib/oracle/...)
# is usually read-only and does not require write permissions for the application at runtime.
# If your specific use case requires writing to other paths within the container,
# you'll need to set appropriate permissions for those paths as well.

# Set the working directory for your application
WORKDIR /app

# Switch to the non-root user for subsequent instructions and runtime
USER ${APP_USER}

# Optional: Copy your application code or any entrypoint scripts here if this
# is the final image for your specific application that uses Instant Client.
# For example:
# COPY --chown=oracle:oracle my-app /app/my-app
# ENTRYPOINT ["/app/my-app/start.sh"]

# Default command
CMD ["/bin/bash"]
