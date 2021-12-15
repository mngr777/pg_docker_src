FROM ubuntu:focal

# From official PostgreSQL Docker image:
# https://github.com/docker-library/postgres

WORKDIR /

ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Minsk"

# Install dependencies
RUN set -ex \
  && apt-get update \
  && apt-get install -y \
# PostgreSQL
    build-essential \
    libreadline-dev \
    zlib1g-dev \
    flex \
    bison \
    libxml2-dev \
    libxslt-dev \
    libssl-dev \
    libxml2-utils \
    xsltproc \
# PostGIS and dependencies
    curl \
    libboost-all-dev \
    git \
    cmake \
    libcgal-dev \
    autoconf \
    automake \
    autotools-dev \
    libtool \
    libsqlite3-dev \
    sqlite3 \
    libtiff-dev \
    libcurl4-gnutls-dev \
    pkg-config \
    libprotobuf-c1 \
    libprotobuf-c-dev \
    protobuf-c-compiler \
# gdb
    gdb \
    gdbserver

# --------------------
# PostGIS dependencies

# sfcgal
ENV SFCGAL_VERSION master
#current:
#ENV SFCGAL_GIT_HASH b1646552e77acccce74b26686a2e048a74caacb7
#reverted for the last working version
ENV SFCGAL_GIT_HASH e1f5cd801f8796ddb442c06c11ce8c30a7eed2c5

RUN set -ex \
    && mkdir -p /usr/src \
    && cd /usr/src \
    && git clone https://gitlab.com/Oslandia/SFCGAL.git \
    && cd SFCGAL \
    && git checkout ${SFCGAL_GIT_HASH} \
    && mkdir cmake-build \
    && cd cmake-build \
    && cmake .. \
    && make -j$(nproc) \
    && make install \
    && cd / \
    && rm -fr /usr/src/SFCGAL

# proj
ENV PROJ_VERSION master
ENV PROJ_GIT_HASH ac882266b57d04720bb645b8144901127f7427cf

RUN set -ex \
    && cd /usr/src \
    && git clone https://github.com/OSGeo/PROJ.git \
    && cd PROJ \
    && git checkout ${PROJ_GIT_HASH} \
    && ./autogen.sh \
    && ./configure --disable-static \
    && make -j$(nproc) \
    && make install \
    && cd / \
    && rm -fr /usr/src/PROJ

# gdal
ENV GDAL_VERSION master
ENV GDAL_GIT_HASH ab147114c2f1387447c3efc1a7ac7dfc3d7bad9a

RUN set -ex \
    && cd /usr/src \
    && git clone https://github.com/OSGeo/gdal.git \
    && cd gdal \
    && git checkout ${GDAL_GIT_HASH} \
    \
    # gdal project directory structure - has been changed !
    && if [ -d "gdal" ] ; then \
        echo "Directory 'gdal' dir exists -> older version!" ; \
        cd gdal ; \
    else \
        echo "Directory 'gdal' does not exists! Newer version! " ; \
    fi \
    \
    && ./autogen.sh \
    && ./configure --disable-static \
    && make -j$(nproc) \
    && make install \
    && cd / \
    && rm -fr /usr/src/gdal

# GEOS
RUN mkdir /root/geos
COPY ./geos /root/geos
RUN set -ex \
    && cd /root/geos \
    && mkdir cmake-build \
    && cd cmake-build \
    && cmake -DCMAKE_BUILD_TYPE=Debug .. \
    && make -j$(nproc) \
    && make install

# Minimal command line test.
RUN set -ex \
    && ldconfig \
    && cs2cs \
    && gdalinfo --version \
    && geos-config --version \
    && ogr2ogr --version \
    && proj \
    && sfcgal-config --version


# --------------------
# grab gosu for easy step-down from root
# (required by docker-entrypoint)
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.14
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true


# --------------------
# PostgreSQL

# Build PostgreSQL
RUN mkdir /root/postgres
COPY ./postgres /root/postgres
RUN set -ex \
  && cd /root/postgres \
  && ./configure --enable-cassert --enable-debug CFLAGS="-ggdb -Og -g3 -fno-omit-frame-pointer" \
  && make \
  && make install

# update PATH
ENV PATH $PATH:/usr/local/pgsql/bin

# Create `postgres' user and group
RUN set -ex; \
  groupadd -r postgres --gid=999; \
  useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
  mkdir -p /var/lib/postgresql; \
  chown -R postgres:postgres /var/lib/postgresql

# Create /var/run directory
RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

# Create data volume
ENV PGDATA /var/lib/postgresql/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/postgresql/data


# --------------------
# PostGIS

RUN mkdir /root/postgis
COPY --chown=root:root ./postgis /root/postgis
RUN cd /root/postgis \
    && ./autogen.sh \
    && CFLAGS='-ggdb -Og -g3 -fno-omit-frame-pointer -Wall -Wextra -Wformat -Werror=format-security -Wno-unused-parameter -Wno-implicit-fallthrough -Wno-unknown-warning-option -Wno-cast-function-type -fno-math-errno -fno-signed-zeros' ./configure \
#       --with-gui \
        --with-pcredir="$(pcre-config --prefix)" \
    && make -j$(nproc) \
    && make install

# Set up entry point script
ENV PATH $PATH:/usr/local/bin
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh; \
  mkdir /docker-entrypoint-initdb.d

ENTRYPOINT ["docker-entrypoint.sh"]
STOPSIGNAL SIGINT
EXPOSE 5432
EXPOSE 2345
CMD ["postgres"]
