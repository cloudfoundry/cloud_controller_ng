shared_examples "updating" do |opts|
  opts[:extra_attributes] ||= {}

  describe "updating" do
    let(:creation_opts) do
      opts[:create_attribute_reset].call if opts[:create_attribute_reset]

      initial_obj = opts[:model].make
      attrs = CreationOptionsFromObject.options(initial_obj, opts)
      initial_obj.destroy

      opts[:extra_attributes].each do |attr, val|
        attrs[attr.to_s] = val.respond_to?(:call) ? val.call : val
      end

      attrs
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
        before do
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
      end

      #
      # make sure we get failures if all of the unique attributes are the
      # same
      #
      dup_attrs = opts.fetch(:unique_attributes, []).dup
      dup_attrs = dup_attrs - ["id"]
      unless dup_attrs.empty?
        desc = dup_attrs.map { |v| ":#{v}" }.join(", ")
        desc = "[#{desc}]" if opts[:unique_attributes].length > 1
        context "with duplicate #{desc}" do
          before do
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