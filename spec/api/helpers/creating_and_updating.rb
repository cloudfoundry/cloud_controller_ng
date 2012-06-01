# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper

  shared_examples "creating and updating" do |opts|
    describe "creating and updating" do
      # we use the template object to automatically get values
      # to use during creation from sham
      template_obj = TemplateObj.new(opts[:model], opts[:required_attributes])

      let(:creation_opts) do
        # we potentially need to regenerate associations as the db
        # gets wiped between tests
        template_obj.refresh
        attrs = template_obj.attributes.dup

        opts[:extra_attributes].each do |attr|
          if opts[:required_attributes].include?(attr)
            attrs[attr.to_s] = Sham.send(attr)
          end
        end

        attrs
      end

      let(:non_synthetic_creation_opts) do
        res = {}
        creation_opts.each do |k, v|
          res[k] = v unless opts[:extra_attributes].include?(k)
        end
        res
      end

      [:post, :put].each do |verb|
        path_desc = opts[:path]
        path_desc = "#{opts[:path]}/:guid" if verb == :put
        describe "#{verb.to_s.upcase} #{path_desc}" do
          context "with all required attributes" do
            before do
              json_body = Yajl::Encoder.encode(creation_opts)

              case verb
              when :post
                post opts[:path], json_body, json_headers(admin_headers)
              when :put
                obj = opts[:model].make creation_opts
                @orig_created_at = obj.created_at
                put("#{opts[:path]}/#{obj.guid}",
                    json_body, json_headers(admin_headers))
              end
            end

            it "should return 201" do
              last_response.status.should == 201
            end

            include_examples "return a vcap rest encoded object"

            it "should return the json encoded object in the entity hash" do
              non_synthetic_creation_opts.keys.each do |k|
                unless k == "guid"
                  entity[k.to_s].should_not be_nil
                  entity[k.to_s].should == creation_opts[k]
                end
              end
            end

            case verb
            when :post
              it "should return the path to the new instance in the location header" do
                last_response.location.should_not be_nil
                last_response.location.should match /#{opts[:path]}\/[^ \/]/
                metadata["url"].should == last_response.location
              end

              it "should have created the object pointed to in the location header" do
                obj_id = last_response.location.split('/').last
                obj = opts[:model].find(:guid => obj_id)
                non_synthetic_creation_opts.keys.each do |k|
                  obj.send(k).should == creation_opts[k]
                end
              end

              it "should have a recent created_at timestamp" do
                Time.parse(metadata["created_at"]).should be_recent
              end

              it "should not have an updated_at timestamp" do
                metadata["updated_at"].should be_nil
              end
            when :put
              it "should not update the created_at timestamp" do
                metadata["created_at"].should == @orig_created_at.to_s
              end

              it "should have a recent updated_at timestamp" do
                metadata["updated_at"].should_not be_nil
                Time.parse(metadata["updated_at"]).should be_recent
              end
            end
          end

          #
          # Test each of the required attributes
          #
          req_attrs = opts[:required_attributes].dup
          req_attrs = req_attrs - ["id"] if verb == :put
          req_attrs.each do |without_attr|
            context "without the :#{without_attr.to_s} attribute" do
              let(:filtered_opts) do
                creation_opts.select do |k, v|
                  k != without_attr.to_s and k != "#{without_attr}_id"
                end
              end

              @expected_status = nil

              before do
                case verb
                when :post
                  post opts[:path], Yajl::Encoder.encode(filtered_opts), json_headers(admin_headers)
                when :put
                  obj = opts[:model].make creation_opts
                  put "#{opts[:path]}/#{obj.guid}", Yajl::Encoder.encode(filtered_opts), json_headers(admin_headers)
                end
              end

              case verb
              when :post
                expected_status = 400
              when :put
                expected_status = 201
              end

              it "should return a #{expected_status}" do
                last_response.status.should == expected_status
              end

              it "should not return a location header" do
                last_response.location.should be_nil
              end

              if verb == :post
                it_behaves_like "a vcap rest error response", /invalid/
              end
            end
          end

          #
          # If there are multiple unique attributes, vary them one a time
          #
          if opts[:unique_attributes] and opts[:unique_attributes].length > 1
            opts[:unique_attributes].each do |new_attr|
              new_attr = new_attr.to_s
              context "with duplicate attributes other than #{new_attr}" do
                # FIXME: this is a cut/paste from the model spec, refactor
                let(:dup_opts) do
                  if opts[:model].associations.include?(new_attr)
                    new_attr = "#{new_attr}_id"
                  end

                  # FIXME: this name isn't right now that it is shared with PUT
                  new_creation_opts = creation_opts.dup
                  orig_obj = opts[:model].create new_creation_opts
                  orig_obj.should be_valid

                  create_attribute = opts[:create_attribute]

                  # create the attribute using the caller supplied lambda,
                  # otherwise, create a second template object and fetch
                  # the value from that
                  val = nil
                  if create_attribute
                    # FIXME: do we use this?  do we use it in the model specs
                    val = create_attribute.call(new_attr)
                  end

                  if val.nil?
                    another_obj = TemplateObj.new(opts[:model], opts[:required_attributes])
                    another_obj.refresh
                    val = another_obj.attributes[new_attr]
                  end

                  new_creation_opts[new_attr] = val
                  new_creation_opts
                end

                it "should succeed" do
                  post opts[:path], Yajl::Encoder.encode(dup_opts), json_headers(admin_headers)
                  last_response.status.should == 201
                end
              end
            end
          end

          #
          # make sure we get failures if all of the unique attributes are the
          # same
          #
          dup_attrs = opts[:unique_attributes].dup
          dup_attrs = dup_attrs - ["id"] if verb == :put
          unless dup_attrs.empty?
            desc = dup_attrs.map { |v| ":#{v}" }.join(", ")
            desc = "[#{desc}]" if opts[:unique_attributes].length > 1
            context "with duplicate #{desc}" do
              before do
                obj = opts[:model].make creation_opts
                obj.should be_valid

                case verb
                when :post
                  post opts[:path], Yajl::Encoder.encode(creation_opts), json_headers(admin_headers)
                when :put
                  dup_obj = opts[:model].make
                  put "#{opts[:path]}/#{dup_obj.guid}", Yajl::Encoder.encode(creation_opts), json_headers(admin_headers)
                end
              end

              it "should return 400" do
                last_response.status.should == 400
              end

              it_behaves_like "a vcap rest error response", /taken/
            end
          end

        end
      end
    end
  end
end
