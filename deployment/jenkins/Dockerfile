FROM jenkins/jenkins:2.516.1-jdk21
USER root

# Install Docker CLI, Maven, and other tools
RUN apt-get update && apt-get install -y lsb-release ca-certificates curl maven && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER jenkins

# Install Jenkins plugins for Spring Boot development
RUN jenkins-plugin-cli --plugins \
    "blueocean docker-workflow json-path-api git github github-branch-source pipeline-github-lib \
    maven-plugin junit jacoco pipeline-stage-view timestamper ws-cleanup build-timeout \
    credentials-binding email-ext mailer configuration-as-code"