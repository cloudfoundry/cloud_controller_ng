# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  shared_examples "creation of unique attributes" do |opts|
    #
    # If there are multiple unique attributes, vary them one a time
    #
    if opts[:unique_attributes]
      opts[:unique_attributes].each do |unique_key|
        if unique_key.respond_to?(:each)
          unique_key.each do |changed_attr|
            context "with duplicate attributes other than #{changed_attr}" do
              def valid_attributes(opts)
                opts[:create_attribute_reset].call if opts[:create_attribute_reset]

                initial_template = described_class.make
                orig_opts = creation_opts_from_obj(initial_template, opts)
                initial_template.delete

                orig_obj = described_class.make orig_opts
                orig_obj.should be_valid
                creation_opts_from_obj(orig_obj, opts)
              end

              def value_for_attr(attr, opts)
                # create the attribute using the caller supplied lambda,
                # otherwise, create a second object and fetch
                # the value from that
                val = nil
                if opts[:create_attribute]
                  val = opts[:create_attribute].call(attr)
                end

                if val.nil?
                  another_obj = described_class.make
                  val = another_obj.send(attr)
                  another_obj.delete
                end
                val
              end

              let(:dup_opts) do
                valid_attributes(opts).merge(
                  changed_attr => value_for_attr(changed_attr, opts)
                )
              end

              it "should succeed" do
                obj = described_class.create do |instance|
                  instance.set_all(dup_opts)
                end
                obj.should be_valid
              end
            end
          end
        end

        #
        # make sure we get failures if all of the unique attributes are the
        # same
        #
        desc = opts[:unique_attributes].map { |v| ":#{v}" }.join(", ")
        desc = "[#{desc}]" if opts[:unique_attributes].length > 1
        context "with duplicate #{desc}" do
          let(:column_list) do
            opts[:unique_attributes].flatten.map do |v|
              if described_class.associations.include?(v.to_sym)
                v = v.to_s.concat("_id")
              end
              v
            end
          end

          def sequel_error_for_all_columns?(column_list, error)
            columns_in_error = error.message[/^(.*) unique$/, 1].split(" and ")
            columns_in_error.sort == column_list.sort
          end

          def requires_uniqueness_for_columns?(column_list, error)
            case described_class.db.database_type
            when :mysql
              error.message == "Duplicate entry"
            when :sqlite
              columns_in_error = error.message[/columns? (.*?) (is|are) not unique/, 1]
              columns_in_error.split(', ').sort == column_list.sort
            else
              true
            end
          end

          let(:dup_opts) do
            opts[:create_attribute_reset].call if opts[:create_attribute_reset]
            new_opts = opts.dup
            new_opts[:required_attributes] |= new_opts[:unique_attributes].flatten

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
              described_class.create do |instance|
                instance.set_all(dup_opts)
              end
            }.to raise_error Sequel::ValidationFailed do |err|
              sequel_error_for_all_columns?(column_list, err)
            end
          end

          unless opts[:skip_database_constraints]
            it "should fail due to database integrity checks" do
              expect {
                described_class.new do |instance|
                  instance.set_all(dup_opts)
                  instance.valid?  # run validations but ignore results
                end.save(:validate => false)
              }.to raise_error Sequel::DatabaseError do |err|
                requires_uniqueness_for_columns?(column_list, err)
              end
            end
          end
        end
      end
    end
  end
end
