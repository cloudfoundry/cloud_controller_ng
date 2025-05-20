This is taken from [github.com/cloudfoundry/go-log-cache/rpc/logcache_v1/generate.sh](https://github.com/cloudfoundry/go-log-cache/blob/main/rpc/logcache_v1/generate.sh)

1. Install protoc 30.2 from https://github.com/protocolbuffers/protobuf/releases

2. Generate protobuf files:

```
#!/bin/bash

gem install grpc-tools

tmp_dir=$(mktemp -d)
echo "Temp dir: $tmp_dir"
mkdir -p $tmp_dir/logcache

pushd $tmp_dir
  git clone --depth 1 https://github.com/cloudfoundry/loggregator-api.git
  git clone --depth 1 https://github.com/googleapis/googleapis.git
  mv googleapis/google .
  rm -rf googleapis

  git clone --depth 1 https://github.com/cloudfoundry/go-log-cache.git
  cp go-log-cache/api/v1/*.proto logcache/
  rm -rf go-log-cache
popd

out_dir=$(mktemp -d)
echo "Out dir: $out_dir"
RUBY_OUT=$out_dir/ruby-out
GRPC_OUT=$out_dir/grpc-out
mkdir -p  $RUBY_OUT $GRPC_OUT

protoc --plugin=protoc-gen-grpc=`which grpc_tools_ruby_protoc_plugin` --proto_path=$tmp_dir --ruby_out=$RUBY_OUT --grpc_out=$GRPC_OUT  $tmp_dir/logcache/*.proto
```

3. Copy `$out_dir/ruby_out/logcache/*` and `$out_dir/grpc_out/logcache` into `lib/logcache`.
