FROM ruby:2.6.3-slim
EXPOSE 8080

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

ENV APP_ENV production
ENV BUILD_DEPS "make gcc git"
ENV APPDIR /opt/api
RUN mkdir -p $APPDIR

WORKDIR $APPDIR

# Copy the Gemfile and Gemfile.lock first so bundle install can be cached
COPY Gemfile $APPDIR/
COPY Gemfile.lock $APPDIR/

# Install dependencies and run bundler
RUN apt-get update -y && apt-get install -y wget unzip python-minimal gettext

RUN apt-get install -y $BUILD_DEPS --no-install-recommends && \
    bundle install --without development test && \
    apt-get remove --purge -y $BUILD_DEPS && \
    rm -rf /var/lib/apt /var/lib/dpkg /var/lib/cache /var/lib/log /var/lib/apt/lists/*

# install aws-cli
RUN wget -nv "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" && \
    unzip awscli-bundle.zip && \
    ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws

COPY . $APPDIR

# copy config setup scripts
COPY docker/cmd.sh $APPDIR/

# copy config templates
COPY docker/*.template $APPDIR/config/

RUN chown -R nobody:nogroup $APPDIR
USER nobody

HEALTHCHECK --interval=30m --timeout=5s \
  CMD curl -f http://localhost:8080/v1/dns/ping || exit 1

# Start Unicorn
CMD ["./cmd.sh"]
