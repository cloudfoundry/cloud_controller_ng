FROM ubuntu:bionic
WORKDIR /cloud_controller_ng

ENV DEBIAN_FRONTEND=noninteractive
ENV BUNDLE_GEMFILE /cloud_controller_ng/Gemfile
ENV CLOUD_CONTROLLER_NG_CONFIG /config/cloud_controller_ng.yml
ENV C_INCLUDE_PATH /libpq/include
ENV DYNO #{spec.job.name}-#{spec.index}
ENV LANG en_US.UTF-8
ENV LIBRARY_PATH /libpq/lib
ENV RAILS_ENV production

RUN apt-get update && \
  apt-get install --no-install-recommends -y \
    ca-certificates \
    git \
    bash \
    build-essential \
    curl \
    libxml2-dev \
    libxslt-dev \
    libmariadb-dev \
    libssl-dev \
    tzdata \
    libpq-dev \
    tar \
    wget \
    sudo \
    jq \
    less \
    dnsutils \
    libreadline-dev && \
  rm -rf /var/lib/apt/lists/*

RUN wget https://cache.ruby-lang.org/pub/ruby/2.5/ruby-2.5.5.tar.gz -O /tmp/ruby.tar.gz && \
    cd /tmp/ && \
    tar zxvf /tmp/ruby.tar.gz && \
    ls -alrt /tmp && \
    cd /tmp/ruby-2.5.5 && \
    ./configure && \
    make -j $(nproc) && \
    sudo make install

COPY Gemfile .
COPY Gemfile.lock .

RUN gem install bundler -v 1.17.3 && \
    bundle config build.nokogiri --use-system-libraries && \
    bundle install --without test development

COPY . .
COPY scripts/setup_database.sh .

ENTRYPOINT ["/cloud_controller_ng/bin/cloud_controller", "-c", "/config/cloud_controller_ng.yml"]
