ARG NODE_VERSION=20.18-alpine
FROM node:$NODE_VERSION AS build

WORKDIR /app

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

RUN \
  case "${TARGETPLATFORM}" in \
  'linux/arm64' | 'linux/arm/v7') \
  apk update && \
  apk add --no-cache python3 make g++ gcc libc6-compat bash && \
  yarn global add node-gyp \
  ;; \
  esac

COPY package.json yarn.lock ./
RUN corepack enable \
  && CYPRESS_INSTALL_BINARY=0 yarn install --frozen-lockfile --network-timeout 1000000

COPY . ./

ARG COMMIT_TAG
ENV COMMIT_TAG=${COMMIT_TAG}

  # remove development dependencies
RUN corepack enable \
  && yarn install \
  && yarn build \
  && rm -rf src server .next/cache \
  && touch config/DOCKER \
  && echo "{\"commitTag\": \"${COMMIT_TAG}\"}" > committag.json

FROM node:$NODE_VERSION

WORKDIR /app

RUN apk add --no-cache tzdata tini && rm -rf /tmp/*

# copy from build image
COPY --from=build /app ./
COPY --from=build /app/.yarn ./.yarn

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD [ "yarn", "start" ]

EXPOSE 5055
