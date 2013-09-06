module ControllerHelpers
  shared_examples "updating" do |opts|
    opts[:extra_attributes] ||= {}
    before(:all) do
      reset_database
      configure_stacks
    end

    describe "updating" do
      define_method(:creation_opts) do
        @creation_opts ||= begin
                             # if the caller has supplied their own creation lambda, use it
          opts[:create_attribute_reset].call if opts[:create_attribute_reset]

          initial_obj = opts[:model].make
          attrs = creation_opts_from_obj(initial_obj, opts)
          initial_obj.destroy

          create_attribute = opts[:create_attribute]
          if create_attribute
            opts[:create_attribute_reset].call
            attrs.keys.each do |k|
              v = create_attribute.call k
              attrs[k] = v if v
            end
          end

          opts[:extra_attributes].each do |attr, val|
            attrs[attr.to_s] = val.respond_to?(:call) ? val.call : val
          end

          attrs
        end
      end

      let(:non_synthetic_creation_opts) do
        res = {}
        creation_opts.each do |k, v|
          res[k] = v unless opts[:extra_attributes].keys.include?(k.to_sym)
        end
        res
      end

      path_desc = "#{opts[:path]}/:guid"
      describe "PUT #{path_desc}" do
        context "with all required attributes" do
          before(:all) do
            json_body = Yajl::Encoder.encode(creation_opts)

            obj = opts[:model].make(creation_opts)
            @orig_created_at = obj.created_at
            put("#{opts[:path]}/#{obj.guid}", json_body, json_headers(admin_headers))
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

          it "should not update the created_at timestamp" do
            metadata["created_at"].should_not be_nil
            metadata["created_at"].should == @orig_created_at.iso8601
          end

          it "should have a recent updated_at timestamp" do
            metadata["updated_at"].should_not be_nil
            Time.parse(metadata["updated_at"]).should be_recent
          end
        end

        #
        # Test each of the required attributes
        #
        req_attrs = opts[:required_attributes]
        req_attrs = req_attrs - ['id']
        req_attrs.each do |without_attr|
          context "without the :#{without_attr.to_s} attribute" do
            define_method(:filtered_opts) do
              @filtered_opts ||= begin
                creation_opts.select do |k, _|
                  k != without_attr.to_s and k != "#{without_attr}_id"
                end
              end
            end

            @expected_status = nil

            before(:all) do
              @obj = opts[:model].make creation_opts
              @expected_hash = @obj.to_hash
              put "#{opts[:path]}/#{@obj.guid}", Yajl::Encoder.encode(filtered_opts), json_headers(admin_headers)
            end

            it "should return a 201" do
              last_response.status.should == 201
            end

            it "should not return a location header" do
              last_response.location.should be_nil
            end

            it "should return the request guid in the header" do
              last_response.headers["X-VCAP-Request-ID"].should_not be_nil
            end

            it "should not change attributes other than the ones specified" do
              @obj.refresh
              @expected_hash.should == @obj.to_hash
            end
          end
        end

        #
        # If there are multiple unique attributes, vary them one a time
        #
        opts[:unique_attributes].each do |new_attr|
          new_attr = new_attr.to_s
          context "with duplicate attributes other than #{new_attr}" do
            # FIXME: this is a cut/paste from the model spec, refactor
            let(:orig_obj) do
              # FIXME: this name isn't right now that it is shared with PUT
              orig_obj = opts[:model].create do |instance|
                instance.set_all(creation_opts)
              end
              orig_obj.should be_valid
              orig_obj
            end

            let(:dup_opts) do
              new_creation_opts = creation_opts.dup

              if opts[:model].associations.include?(new_attr)
                new_attr = "#{new_attr}_id"
              end

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
                another_obj = ModelHelpers::TemplateObj.new(opts[:model], opts[:required_attributes])
                another_obj.refresh
                val = another_obj.attributes[new_attr]
              end

              new_creation_opts[new_attr] = val
              new_creation_opts
            end

            it "should succeed" do
              put "#{opts[:path]}/#{orig_obj.guid}", Yajl::Encoder.encode(dup_opts), json_headers(admin_headers)
              last_response.status.should == 201
            end
          end
        end if opts[:unique_attributes] and opts[:unique_attributes].length > 1

        #
        # make sure we get failures if all of the unique attributes are the
        # same
        #
        dup_attrs = opts[:unique_attributes].dup
        dup_attrs = dup_attrs - ["id"]
        unless dup_attrs.empty?
          desc = dup_attrs.map { |v| ":#{v}" }.join(", ")
          desc = "[#{desc}]" if opts[:unique_attributes].length > 1
          context "with duplicate #{desc}" do
            before(:all) do
              obj = opts[:model].make creation_opts
              obj.should be_valid

              dup_obj = opts[:model].make
              put "#{opts[:path]}/#{dup_obj.guid}", Yajl::Encoder.encode(creation_opts), json_headers(admin_headers)
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
