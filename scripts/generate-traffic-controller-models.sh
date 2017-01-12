#!/usr/bin/env bash

ruby_generated_files_path="src/cloud_controller_ng/lib/traffic_controller/models"
traffic_controller_proto_path="${GOPATH}/src/dropsonde-protocol/events"
generated_ruby_destination="${GOPATH}/${ruby_generated_files_path}"

if [[ ! -d $traffic_controller_proto_path ]]; then
  echo "bbs models were not available at ${traffic_controller_proto_path}"
  exit 1
fi

if [[ ! -d "${generated_ruby_destination}" ]]; then
  echo "directory not available for generated ruby classes at ${generated_ruby_destination}"
  exit 1
fi

if [[ ! $(protoc --version) ]]; then
  echo "must install protoc"
  exit 1
fi

# this gem contains the plugin used to generate ruby models that are proto2 compatible
if [[ ! $(gem list | grep protobuf) ]]; then
  echo "must 'gem install protobuf'"
  exit 1
fi

pushd "${traffic_controller_proto_path}"
  # the ruby modules are created based on the package name
  sed -i'' -e 's/package events/package TrafficController.models/' ./*.proto

  # this is a hack to allow protoc to use a plugin that supports proto2 generation since protoc only supports proto3 by default
  # see: https://github.com/ruby-protobuf/protobuf/issues/341
  protoc --proto_path="${GOPATH}/src":. --plugin="protoc-gen-bob=$(which protoc-gen-ruby)" --bob_out="${generated_ruby_destination}" ./*.proto
  git checkout .
popd
