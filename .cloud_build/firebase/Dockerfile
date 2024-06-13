FROM node:lts-slim AS app-env

RUN npm install -g firebase-tools

ADD firebase.bash /usr/bin
RUN chmod +x /usr/bin/firebase.bash

ENTRYPOINT [ "/usr/bin/firebase.bash" ]
