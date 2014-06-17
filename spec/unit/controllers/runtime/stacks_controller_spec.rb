require "spec_helper"

module VCAP::CloudController
  describe StacksController do
    it_behaves_like "an authenticated endpoint", path: "/v2/stacks"
    include_examples "querying objects", path: "/v2/stacks", model: Stack, queryable_attributes: [:name]
    include_examples "enumerating objects", path: "/v2/stacks", model: Stack
    include_examples "reading a valid object", path: "/v2/stacks", model: Stack, basic_attributes: [:name, :description]
  end
end
