FROM centos:7 as build

ARG HADOOP_VERSION=3.1.1
ENV HADOOP_RELEASE_TAG=rel/release-${HADOOP_VERSION}
ENV HADOOP_RELEASE_TAG_RE=".*refs/tags/${HADOOP_RELEASE_TAG}\$"

RUN yum -y update && yum clean all

# newer maven
RUN yum -y install --setopt=skip_missing_names_on_install=False centos-release-scl

# cmake3
RUN yum -y install --setopt=skip_missing_names_on_install=False epel-release

RUN yum -y install --setopt=skip_missing_names_on_install=False \
    git \
    java-1.8.0-openjdk-devel \
    java-1.8.0-openjdk \
    rh-maven33 \
    protobuf protobuf-compiler \
    patch \
    lzo-devel zlib-devel gcc gcc-c++ make autoconf automake libtool openssl-devel fuse-devel \
    cmake3 \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && ln -s /usr/bin/cmake3 /usr/bin/cmake

# Originally, this was a *lot* of COPY layers
RUN git clone -q \
        -b $(git ls-remote --tags https://github.com/apache/hadoop | grep -E "${HADOOP_RELEASE_TAG_RE}" | sed -E 's/.*refs.tags.(rel.*)/\1/g') \
        --single-branch \
        https://github.com/apache/hadoop.git \
        /build

ENV CMAKE_C_COMPILER=gcc CMAKE_CXX_COMPILER=g++

# build hadoop
RUN scl enable rh-maven33 'cd /build && mvn -B -e -Dtest=false -DskipTests -Dmaven.javadoc.skip=true clean package -Pdist,native -Dtar'
# Install prometheus-jmx agent
RUN scl enable rh-maven33 'mvn dependency:get -Dartifact=io.prometheus.jmx:jmx_prometheus_javaagent:0.3.1:jar -Ddest=/build/jmx_prometheus_javaagent.jar'
# Get gcs-connector for Hadoop
RUN scl enable rh-maven33 'cd /build && mvn dependency:get -Dartifact=com.google.cloud.bigdataoss:gcs-connector:hadoop3-2.0.0-RC2:jar:shaded && mv $HOME/.m2/repository/com/google/cloud/bigdataoss/gcs-connector/hadoop3-2.0.0-RC2/gcs-connector-hadoop3-2.0.0-RC2-shaded.jar /build/gcs-connector-hadoop3-2.0.0-RC2-shaded.jar'


FROM registry.access.redhat.com/ubi8/ubi

RUN set -x; yum install --setopt=skip_missing_names_on_install=False -y \
        java-1.8.0-openjdk \
        java-1.8.0-openjdk-devel \
        curl \
        less  \
        procps \
        net-tools \
        bind-utils \
        which \
        jq \
        rsync \
        openssl \
    && yum clean all \
    && rm -rf /tmp/* /var/tmp/*

ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

ENV JAVA_HOME=/etc/alternatives/jre

# Keep this in sync with ARG HADOOP_VERSION above
ENV HADOOP_VERSION 3.1.1

ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_LOG_DIR=$HADOOP_HOME/logs
ENV HADOOP_CLASSPATH=$HADOOP_HOME/share/hadoop/tools/lib/*
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV PROMETHEUS_JMX_EXPORTER /opt/jmx_exporter/jmx_exporter.jar
ENV PATH=$HADOOP_HOME/bin:$PATH

COPY --from=build /build/hadoop-dist/target/hadoop-$HADOOP_VERSION $HADOOP_HOME
COPY --from=build /build/jmx_prometheus_javaagent.jar $PROMETHEUS_JMX_EXPORTER
COPY --from=build /build/gcs-connector-hadoop3-2.0.0-RC2-shaded.jar $HADOOP_HOME/share/hadoop/tools/lib/gcs-connector-hadoop3-2.0.0-RC2-shaded.jar

WORKDIR $HADOOP_HOME

# remove unnecessary doc/src files
RUN rm -rf ${HADOOP_HOME}/share/doc \
    && for dir in common hdfs mapreduce tools yarn; do \
         rm -rf ${HADOOP_HOME}/share/hadoop/${dir}/sources; \
       done \
    && rm -rf ${HADOOP_HOME}/share/hadoop/common/jdiff \
    && rm -rf ${HADOOP_HOME}/share/hadoop/mapreduce/lib-examples \
    && rm -rf ${HADOOP_HOME}/share/hadoop/yarn/test \
    && find ${HADOOP_HOME}/share/hadoop -name *test*.jar | xargs rm -rf

RUN ln -s $HADOOP_HOME/etc/hadoop $HADOOP_CONF_DIR
RUN mkdir -p $HADOOP_LOG_DIR

# https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html
# Java caches dns results forever, don't cache dns results forever:
RUN sed -i '/networkaddress.cache.ttl/d' $JAVA_HOME/lib/security/java.security
RUN sed -i '/networkaddress.cache.negative.ttl/d' $JAVA_HOME/lib/security/java.security
RUN echo 'networkaddress.cache.ttl=0' >> $JAVA_HOME/lib/security/java.security
RUN echo 'networkaddress.cache.negative.ttl=0' >> $JAVA_HOME/lib/security/java.security

# imagebuilder expects the directory to be created before VOLUME
RUN mkdir -p /hadoop/dfs/data /hadoop/dfs/name

# to allow running as non-root
RUN chown -R 1002:0 $HADOOP_HOME /hadoop $HADOOP_CONF_DIR $JAVA_HOME/lib/security/cacerts && \
    chmod -R 774 $HADOOP_HOME /hadoop $HADOOP_CONF_DIR $JAVA_HOME/lib/security/cacerts

VOLUME /hadoop/dfs/data /hadoop/dfs/name

USER 1002

LABEL io.k8s.display-name="OpenShift Hadoop" \
      io.k8s.description="This is an image used by Cost Management to install and run Hadoop." \
      summary="This is an image used by Cost Management to install and run Hadoop." \
      io.openshift.tags="openshift" \
      maintainer="<cost-mgmt@redhat.com>"
