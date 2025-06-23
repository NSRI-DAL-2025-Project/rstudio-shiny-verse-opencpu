# Use builds from launchpad
FROM lcbs2/rstudio-shiny-verse

ARG BRANCH=master
ENV DEBIAN_FRONTEND=noninteractive

RUN \ 
  apt-get update && \
  apt-get upgrade

RUN \
  apt-get install -y \ 
    wget \
    make \
    devscripts \
    apache2-dev \
    apache2 \
    libapreq2-dev \
    libapparmor-dev \
    libcurl4-openssl-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libcairo2-dev \
    libfontconfig-dev \
    xvfb xauth \
    xfonts-base \
    curl \
    libssl-dev \
    libxml2-dev \
    libicu-dev \
    pkg-config \
    libssh2-1-dev \
    locales \
    apt-utils \
    cmake

# Different from debian
RUN \ 
  apt-get install -y language-pack-en-base

RUN \ 
  useradd -ms /bin/bash builder

USER builder

RUN \ 
  cd ~ && \
  wget --quiet https://github.com/opencpu/opencpu-server/archive/${BRANCH}.tar.gz && \
  tar xzf ${BRANCH}.tar.gz && rm ${BRANCH}.tar.gz && \
  cd opencpu-server-* && \
  dpkg-buildpackage -us -uc -d

USER root

RUN \ 
  apt-get install -y \
   software-properties-common \
   gdebi-core \
   git \
   sudo \
   cron

RUN \ 
  add-apt-repository -y ppa:opencpu/opencpu-2.2

RUN \ 
  gdebi --non-interactive /home/builder/opencpu*.deb

# Inject CORS settings
RUN echo '<Directory "/usr/lib/opencpu/www">
  Header set Access-Control-Allow-Origin "*"
  Header set Access-Control-Allow-Methods "GET, POST, OPTIONS"
  Header set Access-Control-Allow-Headers "Content-Type"
</Directory>' > /etc/apache2/conf-available/opencpu-cors.conf

# Enable headers module and the new config
RUN a2enmod headers && a2enconf opencpu-cors

# create init scripts
RUN \
  mkdir -p /etc/services.d/opencpu-server && \
  echo "#!/usr/bin/with-contenv bash" >> /etc/services.d/opencpu-server/run && \
  echo "## load /etc/environment vars first:" >> /etc/services.d/opencpu-server/run && \
  echo "exec apachectl -DFOREGROUND" >> /etc/services.d/opencpu-server/run && \
  chmod +x /etc/services.d/opencpu-server/run  

RUN \ 
  mkdir -p /etc/services.d/cron && \
  echo "#!/usr/bin/with-contenv bash" >> /etc/services.d/cron/run && \ 
  echo "## load /etc/environment vars first:" >> /etc/services.d/cron/run && \
  echo "exec service cron start" >> /etc/services.d/cron/run && \
  chmod +x /etc/services.d/cron/run

# Prints apache logs to stdout
RUN \
  ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
  ln -sf /proc/self/fd/1 /var/log/apache2/error.log && \
  ln -sf /proc/self/fd/1 /var/log/opencpu/apache_access.log && \
  ln -sf /proc/self/fd/1 /var/log/opencpu/apache_error.log

# Set opencpu password so that we can login
RUN \
  echo "opencpu:opencpu" | chpasswd

# Apache ports
EXPOSE 80
EXPOSE 443
EXPOSE 8004

# Start non-daemonized webserver
#CMD \init && service cron start && apachectl -DFOREGROUND
CMD ["/init"]
