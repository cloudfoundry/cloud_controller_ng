FROM ruby:2.7-alpine

RUN apk --no-cache add git make curl jq build-base \
    && git clone https://github.com/cloudfoundry/cf-acceptance-tests \
    --filter=blob:none \
    --depth=1 \
    -b $(curl -s https://api.github.com/repos/cloudfoundry/cf-acceptance-tests/releases/latest | jq -r '.tag_name') \
    --single-branch

WORKDIR /cf-acceptance-tests/assets/service_broker
RUN git checkout $(curl -s https://api.github.com/repos/cloudfoundry/cf-acceptance-tests/releases/latest | jq -r '.tag_name') \
    && bundle install

EXPOSE 80

ENTRYPOINT ["bundle"]
CMD ["exec", "rackup", "--host", "0.0.0.0"]