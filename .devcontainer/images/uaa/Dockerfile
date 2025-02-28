# Build image
FROM sapmachine:21-jdk-headless-ubuntu-jammy AS builder

WORKDIR /uaa

RUN apt-get  update && apt-get install jq git curl -y \
  && git clone -b $(curl -s https://api.github.com/repos/cloudfoundry/uaa/releases/latest | jq -r '.tag_name') https://github.com/cloudfoundry/uaa.git . --recursive --depth=1 --shallow-submodules \
  && ./gradlew -Pversion=$(curl -s https://api.github.com/repos/cloudfoundry/uaa/releases/latest | jq -r '.tag_name') clean build -x test

FROM mikefarah/yq:4 AS yq

COPY --from=builder /uaa/scripts/cargo/uaa.yml /uaa.yml

# Change to root user
USER root

# Adapt issuer URI
# Copy to uaa URL
RUN yq  e '.issuer.uri = "http://localhost:8080"' -i /uaa.yml \
  && yq e '.uaa.url = .issuer.uri' -i /uaa.yml

# Runtime image
FROM tomcat:9-jdk21

# Copy config file from yq image
COPY --from=yq /uaa.yml /uaa.yml

# Remove pre-installed apps
RUN rm  -rf /usr/local/tomcat/webapps/*

# Copy CF users
RUN mkdir -p /usr/local/cf_config
COPY uaa.yml /usr/local/cf_config/uaa.yml


# Install war from build image
COPY --from=builder /uaa/uaa/build/libs/cloudfoundry-identity-uaa-*.war /usr/local/tomcat/webapps/ROOT.war
COPY --from=builder /uaa/k8s/templates/log4j2.properties /log4j2.properties

ENV JAVA_OPTS="-DLOGIN_CONFIG_URL=file:///uaa.yml -Dlogging.config=/log4j2.properties -DCLOUDFOUNDRY_CONFIG_PATH=/usr/local/cf_config"
ENV spring_profiles=default

EXPOSE 8080