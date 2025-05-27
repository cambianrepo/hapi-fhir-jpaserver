FROM docker.io/library/maven:3.9.6-eclipse-temurin-17 AS build-hapi
WORKDIR /tmp/hapi-fhir-jpaserver-starter

ARG OPENTELEMETRY_JAVA_AGENT_VERSION=1.33.3
RUN curl -LSsO https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OPENTELEMETRY_JAVA_AGENT_VERSION}/opentelemetry-javaagent.jar

COPY pom.xml .
COPY server.xml .
RUN mvn -ntp dependency:go-offline

COPY src/ /tmp/hapi-fhir-jpaserver-starter/src/
RUN mvn clean install -DskipTests -Djdk.lang.Process.launchMechanism=vfork

##########################################################################
###  Build the distroless stage with the /app and /app/target
FROM build-hapi AS build-distroless
RUN mvn package -DskipTests spring-boot:repackage -Pboot
RUN mkdir /app && cp /tmp/hapi-fhir-jpaserver-starter/target/ROOT.war /app/main.war

# Create the target directory with proper ownership and permissions.
RUN mkdir -p /app/target/lucenefiles && \
    chown -R 65532:65532 /app/target/lucenefiles && \
    chmod 1777 /app/target/lucenefiles
RUN mkdir -p /tmp_rwx && \
    chown -R 65532:65532 /tmp_rwx && \
    chmod 1777 /tmp_rwx
RUN chown -R 65532:65532 /tmp && \
    chmod 1777 /tmp


##########################################################################
### The bitnami stage is not used in production,
### it can be built using eg. `docker build --target tomcat .`
########### bitnami tomcat version is suitable for debugging and comes with a shell
FROM bitnami/tomcat:10.1 AS tomcat

RUN rm -rf /opt/bitnami/tomcat/webapps/ROOT && \
    mkdir -p /opt/bitnami/hapi/data/hapi/lucenefiles && \
    chmod 775 /opt/bitnami/hapi/data/hapi/lucenefiles

USER root
RUN mkdir -p /target && chown -R 1001:1001 target
USER 1001

COPY --chown=1001:1001 catalina.properties /opt/bitnami/tomcat/conf/catalina.properties
COPY --chown=1001:nonroot server.xml /opt/bitnami/tomcat/conf/server.xml
COPY --chown=1001:1001 /tmp/hapi-fhir-jpaserver-starter/target/ROOT.war /opt/bitnami/tomcat/webapps/ROOT.war
COPY --chown=1001:1001 /tmp/hapi-fhir-jpaserver-starter/opentelemetry-javaagent.jar /app

ENV ALLOW_EMPTY_PASSWORD=yes

########### Intermediate stage to prepare /tmp symlink
FROM debian:bullseye-slim AS symlink-stage
# Create a writable directory that you plan to mount at runtime,
# remove any existing /tmp, and then symlink /tmp to /tmp_rw.
# RUN mkdir -p /tmp_rw && rm -rf /tmp && ln -s /tmp_rw /tmp  

########### distroless brings focus on security and runs on plain spring boot - this is the default image
FROM gcr.io/distroless/java17-debian12:nonroot AS default
# 65532 is the nonroot user's uid
# used here instead of the name to allow Kubernetes to easily detect that the container
# is running as a non-root (uid != 0) user.
USER 65532:65532
WORKDIR /app

# Copy the application from the build-distroless stage
COPY --chown=nonroot:nonroot --from=build-distroless /app /app
# Copy the OpenTelemetry agent
COPY --chown=nonroot:nonroot --from=build-hapi /tmp/hapi-fhir-jpaserver-starter/opentelemetry-javaagent.jar /app
# Copy the prepared /tmp from the symlink-stage
# COPY --from=symlink-stage /tmp /tmp  --- fails in Fargate

ENTRYPOINT ["java", "--class-path", "/app/main.war", "-Dloader.path=main.war!/WEB-INF/classes/,main.war!/WEB-INF/,/app/extra-classes", "org.springframework.boot.loader.PropertiesLauncher"]
