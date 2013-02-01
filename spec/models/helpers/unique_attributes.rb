# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  shared_examples "creation of unique attributes" do |opts|
    #
    # If there are multiple unique attributes, vary them one a time
    #
    if opts[:unique_attributes]
      if opts[:unique_attributes].length > 1
        opts[:unique_attributes].each do |new_attr|
          context "with duplicate attributes other than #{new_attr}" do
            let(:dup_opts) do
              create_attribute = opts[:create_attribute]
              opts[:create_attribute_reset].call if opts[:create_attribute_reset]

              initial_template = described_class.make
              orig_opts = creation_opts_from_obj(initial_template, opts)
              initial_template.delete

              orig_obj = described_class.make orig_opts
              orig_obj.should be_valid

              new_creation_opts = creation_opts_from_obj(orig_obj, opts)

              # create the attribute using the caller supplied lambda,
              # otherwise, create a second object and fetch
              # the value from that
              val = nil
              if create_attribute
                val = create_attribute.call(new_attr)
              end

              if val.nil?
                another_obj = described_class.make
                val = another_obj.send(new_attr)
                another_obj.delete
              end

              new_creation_opts[new_attr] = val
              new_creation_opts
            end

            it "should succeed" do
              obj = described_class.create dup_opts
              obj.should be_valid
            end
          end
        end
      end

      #
      # make sure we get failures if all of the unique attributes are the
      # same
      #
      if opts[:unique_attributes].length >= 1
        desc = opts[:unique_attributes].map { |v| ":#{v}" }.join(", ")
        desc = "[#{desc}]" if opts[:unique_attributes].length > 1
        context "with duplicate #{desc}" do
          let(:column_list) do
            opts[:unique_attributes].map do |v|
              if described_class.associations.include?(v.to_sym)
                v = v.to_s.concat("_id")
              end
              v
            end
          end

          let(:sequel_exception_match) do
            "#{column_list.join(" and ")} unique"
          end

          let(:db_exception_match) do
            case described_class.db.database_type
            when :mysql
              "Duplicate entry"
            when :sqlite
              "columns? #{column_list.join(", ")} .* not unique".sub("uaa_id", "guid")
            else
              ".*"
            end
          end

          let(:dup_opts) do
            opts[:create_attribute_reset].call if opts[:create_attribute_reset]
            new_opts = opts.dup
            new_opts[:required_attributes] |= new_opts[:unique_attributes]

            initial_template = described_class.make
            orig_opts = creation_opts_from_obj(initial_template, new_opts)

            initial_template.destroy

            described_class.make orig_opts
            orig_opts
          end

          it "should fail due to Sequel validations" do
            # TODO: swap out everything but the unique entries for more
            # accurate testing
            expect {
              described_class.create dup_opts
            }.to raise_error Sequel::ValidationFailed, /#{sequel_exception_match}/
          end

          unless opts[:skip_database_constraints]
            it "should fail due to database integrity checks" do
              expect {
                described_class.new(dup_opts).save(:validate => false)
              }.to raise_error Sequel::DatabaseError, /#{db_exception_match}/
            end
          end
        end
      end
    end
  end
end
