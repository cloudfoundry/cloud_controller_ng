# Build image
FROM openjdk:11.0-jdk AS builder

WORKDIR /uaa

# Patch admin client, add authority password.write
COPY PatchAdminOAuthClient.java /PatchAdminOAuthClient.java
RUN apt-get  update && apt-get install jq -y \
  && git clone -b $(curl -s https://api.github.com/repos/cloudfoundry/uaa/releases/latest | jq -r '.tag_name') https://github.com/cloudfoundry/uaa.git . --recursive --depth=1 --shallow-submodules \
  && git clone -b $(curl -s https://api.github.com/repos/pivotal/credhub-release/releases/latest | jq -r '.tag_name') https://github.com/pivotal/credhub-release /credhub-release --recursive --depth=1 --shallow-submodules \
  && javac /PatchAdminOAuthClient.java -d / \
  && java -cp / PatchAdminOAuthClient uaa/src/main/webapp/WEB-INF/spring/oauth-clients.xml \
  && ./gradlew -Pversion=$(curl -s https://api.github.com/repos/cloudfoundry/uaa/releases/latest | jq -r '.tag_name') clean build -x test

FROM mikefarah/yq:4.9.6 AS yq
# Newer versions don't work. The following error is shown but the build is not aborted:
#   safelyRenameFile [ERRO] Failed copying from /tmp/temp<...> to /uaa.yml
#   safelyRenameFile [ERRO] open /uaa.yml: permission denied
#   safelyRenameFile [ERRO] Failed copying from /tmp/temp<...> to /credhub-uaa.yml
#   safelyRenameFile [ERRO] open /credhub-uaa.yml: permission denied

COPY --from=builder /uaa/scripts/cargo/uaa.yml /uaa.yml
COPY --from=builder /credhub-release/src/credhub/config/uaa.yml /credhub-uaa.yml

# Adapt issuer URI
# Copy to uaa URL
# Remove jwt node with symmetric key
# Replace UAA client name in credhub config
# Concatenate modified cargo and credhub config files
RUN yq  e '.issuer.uri = "http://localhost:8080"' -i /uaa.yml \
  && yq e '.uaa.url = .issuer.uri' -i /uaa.yml \
  && yq e 'del(.jwt)' -i /uaa.yml \
  && yq e '.oauth.clients.director_to_credhub = .oauth.clients.credhub_client' -i /credhub-uaa.yml \
  && yq e 'del(.oauth.clients.credhub_client)' -i /credhub-uaa.yml \
  && yq ea 'select(fi == 0) * select(fi == 1)' -i /uaa.yml /credhub-uaa.yml

# Runtime image
FROM tomcat:9-jdk11

# Copy config file from yq image
COPY --from=yq /uaa.yml /uaa.yml

# Remove pre-installed apps
RUN rm  -rf /usr/local/tomcat/webapps/*

# Install war from build image
COPY --from=builder /uaa/uaa/build/libs/cloudfoundry-identity-uaa-*.war /usr/local/tomcat/webapps/ROOT.war
COPY --from=builder /uaa/k8s/templates/log4j2.properties /log4j2.properties

ENV JAVA_OPTS="-DLOGIN_CONFIG_URL=file:///uaa.yml -Dlogging.config=/log4j2.properties"
ENV spring_profiles=default

EXPOSE 8080