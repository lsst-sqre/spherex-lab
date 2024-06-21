FROM python:3.12 as base-image
USER root
SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /tmp/build
WORKDIR /tmp/build

COPY scripts/install-base-packages /tmp/build
RUN ./install-base-packages

# Now we have a patched python container.  Add system dependencies.

FROM base-image as deps-image
COPY scripts/install-dependency-packages /tmp/build
RUN ./install-dependency-packages

# Add our new unprivileged user.

FROM deps-image as user-image

COPY scripts/make-user /tmp/build
RUN ./make-user

# Give jupyterlab ownership to unprivileged user

RUN mkdir -p /usr/local/share/jupyterlab /opt/spherex && \
    chown spherex_local:spherex_local \
    /usr/local/share/jupyterlab /opt/spherex /tmp/build

# Switch to unprivileged user

USER spherex_local:spherex_local

# Add the SPHEREx stack.

FROM user-image as base-stack-image

COPY scripts/install-spherex /tmp/build
COPY spherex-pipelines-base.yml /tmp/build
RUN ./install-spherex

#COPY scripts/generate-versions /tmp/build
#RUN ./generate-versions

#FROM manifests-rsp-image as rsp-image


# Clean up.
# This needs to be numeric, since we will remove /etc/passwd and friends
# while we're running.
USER 0:0
WORKDIR /

COPY scripts/cleanup-files /
RUN ./cleanup-files
RUN rm ./cleanup-files

# Back to unprivileged
USER 1000:1000
WORKDIR /tmp

CMD ["/bin/bash", "-l"]
# Overwrite Stack Container definitions with more-accurate-for-us ones
ENV  DESCRIPTION="SPHEREx Lab"
ENV  SUMMARY="SPHEREx Jupyterlab environment"
