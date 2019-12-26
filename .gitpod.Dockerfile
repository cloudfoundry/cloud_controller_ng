FROM gitpod/workspace-postgres

#CloudController Specifics
ENV DB=postgres
ENV DB_CONNECTION_STRING=postgres://postgres@localhost:5432/cc_run
ENV POSTGRES_CONNECTION_PREFIX=postgres://postgres@localhost:5432

RUN wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add - && \
    echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list

RUN sudo apt-get -q update && \
    sudo apt-get install -yq cf7-cli build-essential patch zlib1g-dev liblzma-dev libmysqlclient-dev libssl-dev libpq-dev && \
    sudo rm -rf /var/lib/apt/lists/*

# Preinstall CC dependencies
ENV GEM_HOME=$HOME/.rvm
ENV PATH=$PATH:$GEM_HOME/bin:$GEM_HOME/gems/default/bin

RUN git clone https://github.com/cloudfoundry/cloud_controller_ng/ --depth 1 \
    && cd cloud_controller_ng \
    && bash -lc "rvm install $(cat .ruby-version | grep -E -o -e '([0-9]+\.)+[0-9]*')" \
    && bash -lc "rvm use $(cat .ruby-version | grep -E -o -e '([0-9]+\.)+[0-9]*') --default" \
    && gem install bundler -v $(cat Gemfile.lock | grep -A1 "BUNDLED WITH" | grep -E -o -e "([0-9]+\.)+[0-9]*") \
    && bash -lc "bundle install -j 16 --path vendor/bundle"
