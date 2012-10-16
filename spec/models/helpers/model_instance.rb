# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  def creation_opts_from_obj(obj, opts)
    attribute_names = opts[:required_attributes]
   create_attribute = opts[:create_attribute]

    attrs = {}
    attribute_names.each do |attr_name|
      v = create_attribute.call(attr_name) if create_attribute
      v ||= obj.send(attr_name)
      attrs[attr_name] = v
    end
    attrs
  end

  shared_context "model template" do |opts|
    # we use the template object to automatically get values
    # to use during creation from sham
    template_obj = TemplateObj.new(described_class, opts[:required_attributes])

    let(:creation_opts) do
      # we potentially need to regenerate associations as the db
      # gets wiped between tests
      template_obj.refresh
      create_opts = template_obj.attributes

      # if the caller has supplied their own creation lambda, use it
      create_attribute = opts[:create_attribute]
      if create_attribute
        opts[:create_attribute_reset].call
        create_opts.keys.each do |k|
          v = create_attribute.call k
          create_opts[k] = v if v
        end
      end

      create_opts
    end
  end

  shared_examples "model instance" do |opts|
    include_context "model template", opts

    describe "creation" do
      include_examples "creation with all required attributes", opts
      include_examples "creation without an attribute", opts
      include_examples "creation of unique attributes", opts
    end

    describe "updates" do
      include_examples "timestamps", opts
    end

    describe "attribute normalization" do
      include_examples "attribute normalization", opts
    end

    describe "serialization" do
      include_examples "serialization", opts
    end

    describe "deserialization" do
      include_examples "deserialization", opts
    end

    describe "deletion" do
      let(:obj) { described_class.make }

      it "should succeed" do
        obj.destroy
      end
    end
  end
end
