FROM google/dart-runtime:2.0.0-dev.59.0

# We install memcached and remove the apt-index again to keep the
# docker image diff small.
RUN apt-get update && \
    apt-get install -y memcached && \
    apt-get install -y unzip && \
    rm -rf /var/lib/apt/lists/*

# Clear out any arguments the base images might have set and ensure we start
# memcached and wait for it to come up before running the Dart app.
CMD []
ENTRYPOINT service memcached start && sleep 1 && /bin/bash /dart_runtime/dart_run.sh
