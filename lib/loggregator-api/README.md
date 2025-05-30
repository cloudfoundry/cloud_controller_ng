To generate the envelope_pb.rb file:

1. Install protoc 30.2 from https://github.com/protocolbuffers/protobuf/releases

2. Generate protobuf files:

```
#!/bin/bash

tmp_dir=$(mktemp -d)

pushd $tmp_dir
  git clone https://github.com/cloudfoundry/loggregator-api

  protoc --ruby_out=. loggregator-api/v2/envelope.proto
popd
```

3. Copy `$tmp_dir/envelope_pb.rb` to CC's `lib/loggregator-api/v2/`.