# Copyright (c) 2009-2012 VMware, Inc.

module ModelHelpers
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
    # template_obj = ModelHelpers::TemplateObj.new(described_class, opts[:required_attributes])

    let(:creation_opts) do
      template_obj = described_class.make
      o = creation_opts_from_obj(template_obj, opts)
      template_obj.destroy
      o
    end
  end

  shared_examples "model instance" do |opts|
    include_context "model template", opts

    unless opts[:disable_examples].include? :creation
      describe "creation" do
        include_examples "creation with all required attributes", opts
        include_examples "creation without an attribute", opts
        include_examples "creation of unique attributes", opts
      end
    end

    unless opts[:disable_examples].include? :updates
      describe "updates" do
        include_examples "timestamps", opts
      end
    end

    unless opts[:disable_examples].include? :attribute_normalization
      describe "attribute normalization" do
        include_examples "attribute normalization", opts
      end
    end

    unless opts[:disable_examples].include? :seralization
      describe "serialization" do
        include_examples "serialization", opts
      end
    end

    unless opts[:disable_examples].include? :deserialization
      describe "deserialization" do
        include_examples "deserialization", opts
      end
    end

    unless opts[:disable_examples].include? :deletion
      describe "deletion" do
        let(:obj) { described_class.make }

        it "should succeed" do
          obj.destroy
        end
      end
    end
  end
end
