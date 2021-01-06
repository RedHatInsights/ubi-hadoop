FROM registry.access.redhat.com/ubi8/ubi

USER root

# Container app versions
ARG HADOOP_VERSION=3.3.0
ARG PROMETHEUS_JMX_EXPORTER_VER=0.14.0

# Container environment
ENV PREFIX=/opt
ENV HADOOP_HOME=${PREFIX}/hadoop-${HADOOP_VERSION}
ENV HADOOP_LOG_DIR=${HADOOP_HOME}/logs
ENV HADOOP_CLASSPATH=${HADOOP_HOME}/share/hadoop/tools/lib/*
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV PATH=${HADOOP_HOME}/bin:${PATH}
ENV TERM=linux
ENV JAVA_HOME=/etc/alternatives/jre_11_openjdk
ENV PROMETHEUS_JMX_EXPORTER=/opt/jmx_exporter/jmx_exporter.jar

# Setup base packages
RUN set -x; \
    INSTALL_PKGS="java-11-openjdk java-11-openjdk-devel openssl less curl rsync diffutils maven" \
    && yum clean all \
    && rm -rf /var/cache/yum/* \
    && yum install --setopt=skip_missing_names_on_install=False -y $INSTALL_PKGS \
    && yum clean all \
    && rm -rf /var/cache/yum 

# Install prometheus-jmx agent
RUN mvn -B dependency:get \
           -Dartifact=io.prometheus.jmx:jmx_prometheus_javaagent:${PROMETHEUS_JMX_EXPORTER_VER}:jar \
           -Ddest=${PROMETHEUS_JMX_EXPORTER} \
    && yum remove -y maven \
    && yum clean all \
    && rm -rf /var/cache/yum

# Download and install Hadoop
RUN curl -sLo ${PREFIX}/hadoop-${HADOOP_VERSION}.tar.gz \
         "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
    && tar -C ${PREFIX} -zxf ${PREFIX}/hadoop-${HADOOP_VERSION}.tar.gz \
    && rm -f ${PREFIX}/hadoop-${HADOOP_VERSION}.tar.gz \
    && ln -s ${HADOOP_HOME} ${PREFIX}/hadoop \
    && ln -s ${HADOOP_HOME}/etc/hadoop ${HADOOP_CONF_DIR} \
    && mkdir -p ${HADOOP_LOG_DIR} \
    && mkdir -p /hadoop/dfs/data \
    && mkdir -p /hadoop/dfs/name \
    && chown -R 1002:0 ${PREFIX} /hadoop ${HADOOP_CONF_DIR} \
    && chmod -R 774 ${PREFIX} /hadoop ${HADOOP_CONF_DIR} /etc/passwd \
    && chmod -R 777 ${HADOOP_LOG_DIR} \
    && chmod -R g+rwx $(readlink -f ${JAVA_HOME}) \
             $(readlink -f ${JAVA_HOME}/lib/security) \
             $(readlink -f ${JAVA_HOME}/lib/security/cacerts)

# Java security config
RUN touch $JAVA_HOME/lib/security/java.security && \
    sed -i -e '/networkaddress.cache.ttl/d' \
        -e '/networkaddress.cache.negative.ttl/d' \
        $JAVA_HOME/lib/security/java.security && \
    printf 'networkaddress.cache.ttl=0\nnetworkaddress.cache.negative.ttl=0\n' >> $JAVA_HOME/lib/security/java.security

RUN useradd hadoop -m -u 1002 -d ${HADOOP_HOME}

VOLUME /hadoop/dfs/data /hadoop/dfs/name ${HADOOP_LOG_DIR}

USER 1002

LABEL io.k8s.display-name="OpenShift Hadoop" \
      io.k8s.description="This is an image used by Cost Management to install and run Hadoop." \
      summary="This is an image used by Cost Management to install and run Hadoop." \
      io.openshift.tags="openshift" \
      maintainer="<cost-mgmt@redhat.com>"
