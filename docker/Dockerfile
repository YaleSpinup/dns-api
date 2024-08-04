FROM ruby:2.6.6-slim
EXPOSE 8080

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

ENV APP_ENV production
ENV BUILD_DEPS "make gcc git"
ENV APPDIR /opt/api
RUN mkdir -p $APPDIR
WORKDIR $APPDIR

# Install Deco
ARG DECO_VERSION=1.4.1
ARG DECO_OS=linux
ARG DECO_ARCH=amd64
ADD https://github.com/YaleUniversity/deco/releases/download/v${DECO_VERSION}/deco_${DECO_VERSION}_${DECO_OS}_${DECO_ARCH}.tar.gz /usr/local/bin/deco.tar.gz
RUN cd /usr/local/bin && tar -zxvf deco.tar.gz && rm -f deco.tar.gz && chmod 555 deco && /usr/local/bin/deco version

# Copy the Gemfile and Gemfile.lock first so bundle install can be cached
COPY Gemfile* $APPDIR/

# Install dependencies and run bundler
RUN echo "running apt update and install:" && apt-get update && echo && \
    apt-get install -y $BUILD_DEPS --no-install-recommends
RUN gem install bundler:2.1.4 && \
    bundle install --without development test && \
    apt-get remove --purge -y $BUILD_DEPS && \
    rm -rf /var/lib/apt /var/lib/dpkg /var/lib/cache /var/lib/log /var/lib/apt/lists/*

COPY . $APPDIR

# copy config setup scripts
COPY docker/*_config.sh $APPDIR/

# copy Deco config template
COPY docker/config.yml.deco $APPDIR/config/config.yml
RUN chmod 600 $APPDIR/config/config.yml

RUN chown -R nobody:nogroup $APPDIR
USER nobody

# Start Puma
CMD ./import_config.sh && \
    bundle exec puma -C config/puma.rb -p 8080
