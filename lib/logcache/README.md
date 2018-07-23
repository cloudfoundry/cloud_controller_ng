This is taken from code.cloudfoundry.org/go-log-cache/rpc/logcache_v1/generate.sh

To generate the two logcache egress*pb.rb files:

`grpc_tools_ruby_protoc` comes from doing `gem install grpc-tools`

```
#!/bin/bash


go get github.com/golang/protobuf/{proto,protoc-gen-go}
go get github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway
go get code.cloudfoundry.org/log-cache

tmp_dir=$(mktemp -d)
mkdir -p $tmp_dir/log-cache

trash_dir=$(mktemp -d)

cp $GOPATH/src/code.cloudfoundry.org/log-cache/api/v1/*proto $tmp_dir/log-cache

pushd $tmp_dir
  git clone https://github.com/cloudfoundry/loggregator-api
popd

RUBY_OUT=$trash_dir/log-cache/ruby-out
GRPC_OUT=$trash_dir/log-cache/grpc-out
mkdir -p  $RUBY_OUT $GRPC_OUT
grpc_tools_ruby_protoc \
    $tmp_dir/log-cache/*.proto \
    --go_out=plugins=grpc,Mv2/envelope.proto=code.cloudfoundry.org/go-loggregator/rpc/loggregator_v2:. \
    --ruby_out=$RUBY_OUT \
    --grpc_out=$GRPC_OUT \
    --proto_path=$tmp_dir/log-cache \
    --grpc-gateway_out=logtostderr=true:. \
    -I$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
    -I=/usr/local/include \
    -I=$tmp_dir/log-cache \
    -I=$tmp_dir/loggregator-api/.
```

You want `$trash_dir/log-cache/ruby-out/egress_pb.rb` and  `$trash_dir/log-cache/grpc-out/egress_services_pb.rb`


To generate the two v2/envelope_pb.rb file:

```
mkdir -p $tmp_dir/loggregator-api
cp $GOPATH/src/code.cloudfoundry.org/loggregator-api/v2/*proto $tmp_dir/loggregator-api/

RUBY_OUT=$trash_dir/loggregator-api/ruby-out
GRPC_OUT=$trash_dir/loggregator-api/grpc-out
mkdir -p  $RUBY_OUT $GRPC_OUT
grpc_tools_ruby_protoc \
    $tmp_dir/loggregator-api/*.proto \
    --go_out=plugins=grpc,Mv2/envelope.proto=code.cloudfoundry.org/go-loggregator/rpc/loggregator_v2:. \
    --ruby_out=$RUBY_OUT \
    --grpc_out=$GRPC_OUT \
    --proto_path=$tmp_dir/loggregator-api \
    --grpc-gateway_out=logtostderr=true:. \
    -I$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
    -I=/usr/local/include \
    -I=$tmp_dir/log-cache \
    -I=$GOPATH/src/code.cloudfoundry.org/loggregator-api/.

```

You want `$trash_dir/ruby-out/envelope_pb.rb`
