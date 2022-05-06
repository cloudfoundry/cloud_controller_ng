#!/usr/bin/env bash

bbs_models_path="src/code.cloudfoundry.org/bbs/models"
ruby_generated_files_path="src/cloud_controller_ng/lib/diego/bbs/models"
locket_models_path="src/code.cloudfoundry.org/locket/models"
locket_generated_files_path="src/cloud_controller_ng/lib/locket"

if [[ ! -d "${GOPATH}/${bbs_models_path}" ]]; then
  echo "bbs models were not available at ${GOPATH}/${bbs_models_path}"
  exit 1
fi

if [[ ! -d "${GOPATH}/${ruby_generated_files_path}" ]]; then
  echo "directory not available for generated ruby classes at ${GOPATH}/${ruby_generated_files_path}"
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

pushd "${GOPATH}/${bbs_models_path}"
  # the ruby modules are created based on the package name
  sed -i'' -e 's/package models/package diego.bbs.models/' ./*.proto

  protoc --proto_path="${GOPATH}/src":. --ruby_out="${GOPATH}/${ruby_generated_files_path}" ./*.proto
  git checkout .
popd

pushd "${GOPATH}/${locket_models_path}"
  # the ruby module here shares the same package name as locket models
  protoc --proto_path="${GOPATH}/src":. --ruby_out="${GOPATH}/${locket_generated_files_path}" ./*.proto
  git checkout .
popd
