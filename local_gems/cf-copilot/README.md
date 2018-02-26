### How to build and run a Docker image containing the necessary dependencies

Starting from the repo root:
```
export COPILOT_ROOT=$(pwd)
cd sdk/ruby
docker build -t protobuf-ruby-dependencies .
docker run -v $COPILOT_ROOT:/tmp/copilot -it protobuf-ruby-dependencies /bin/bash
cd /tmp/copilot
```

### How to generate services and messages from the `.proto` file

Starting from the repo root:
```
cd api/protos
protoc --ruby_out=../../sdk/ruby/lib/copilot/protos \
  --grpc_out=../../sdk/ruby/lib/copilot/protos \
  --plugin="protoc-gen-grpc=$(which grpc_tools_ruby_protoc_plugin)" \
  ./cloud_controller.proto
```

### How to build and install the `cf-copilot` ruby gem

Starting from the repo root:
```
cd sdk/ruby
gem build ./cf-copilot.gemspec && gem install cf-copilot
```
