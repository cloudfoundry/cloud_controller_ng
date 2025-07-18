To generate the locket protobuf files:

1. Install protoc 30.2 from https://github.com/protocolbuffers/protobuf/releases

2. Generate protobuf files:

```
#!/bin/bash

gem install grpc-tools

tmp_dir=$(mktemp -d)
echo "Temp dir: $tmp_dir"

pushd $tmp_dir
  git clone --depth 1 "https://github.com/cloudfoundry/locket.git"
  mv locket/models/locket.proto locket/
popd

out_dir=$(mktemp -d)
echo "Out dir: $out_dir"
RUBY_OUT=$out_dir/ruby-out
GRPC_OUT=$out_dir/grpc-out
mkdir -p  $RUBY_OUT $GRPC_OUT

protoc --plugin=protoc-gen-grpc=`which grpc_tools_ruby_protoc_plugin` --proto_path=$tmp_dir --ruby_out=$RUBY_OUT --grpc_out=$GRPC_OUT  $tmp_dir/locket/locket.proto
```

3. Copy `$out_dir/ruby_out/locket/*` and `$out_dir/grpc_out/locket` into `lib/locket`.
