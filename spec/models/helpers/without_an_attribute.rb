# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  shared_examples "creation without an attribute" do |opts|
    opts[:required_attributes].each do |without_attr|
      context "without the :#{without_attr.to_s} attribute" do
        let(:filtered_opts) do
          creation_opts.select do |k, v|
            k != without_attr and k != "#{without_attr}_id"
          end
        end

      it "should fail due to Sequel validations" do
        lambda {
          described_class.create filtered_opts
        }.should raise_error Sequel::ValidationFailed, /#{without_attr}/
      end

      it "should fail due to database integrity checks" do
        msg = without_attr
        msg = :guid if without_attr == :uaa_id

        lambda {
          described_class.new(filtered_opts).save(:validate => false)
        }.should raise_error Sequel::DatabaseError, /#{msg}/
      end
      end
    end
  end
end
