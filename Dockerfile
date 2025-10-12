FROM quay.io/jupyterhub/k8s-singleuser-sample:4.3.0

USER root

RUN echo "Installing packages..." \
    && apt-get update --fix-missing > /dev/null \
    # Add packages in the following line if needed
    && apt-get install -y curl > /dev/null \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER ${NB_USER}
