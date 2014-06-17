require "spec_helper"

module VCAP::CloudController
  describe StacksController do
    include_examples "reading a valid object", path: "/v2/stacks", model: Stack, basic_attributes: [:name, :description]
  end
end
