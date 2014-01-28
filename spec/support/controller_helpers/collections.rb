module ControllerHelpers
  def self.description_for_inline_depth(depth, pagination = 50)
    if depth
      "?inline-relations-depth=#{depth}&results-per-page=#{pagination}"
    else
      ""
    end
  end

  def query_params_for_inline_depth(depth, pagination = 50)
    if depth
      { "inline-relations-depth" => depth, "results-per-page" => pagination }
    else
      { "results-per-page" => pagination }
    end
  end

  def normalize_attributes(value)
    case value
    when Hash
      stringified = {}

      value.each do |k, v|
        stringified[k] = normalize_attributes(v)
      end

      stringified
    when Array
      value.collect { |x| normalize_attributes(x) }
    when Numeric, nil, true, false
      value
    when Time
      value.iso8601
    else
      value.to_s
    end
  end

  shared_context "collections" do |opts, attr, make|
    define_method(:obj) do
      @obj ||= opts[:model].make
    end

    define_method(:child_name) do
      attr.to_s.singularize
    end

    def add_method
      "add_#{child_name}"
    end

    def get_method
      "#{child_name}s"
    end

    def headers
      @header ||= begin
        json_headers(admin_headers)
      end
    end

    before do
      @opts = opts
      @attr = attr
    end

    def do_write(verb, children, expected_result, expected_children)
      body = Yajl::Encoder.encode({"#{child_name}_guids" => children.map { |c| c[:guid] }})
      send(verb, "#{@opts[:path]}/#{obj.guid}", body, headers)
      last_response.status.should == expected_result

      obj.refresh
      obj.send(get_method).length.should == expected_children.length
      expected_children.each { |c| obj.send(get_method).should include(c.refresh) }
    end
  end

  shared_context "inlined_relations_context" do |opts, attr, make, depth|
    before do
      query_parms = query_params_for_inline_depth(depth)
      get "#{opts[:path]}/#{obj.guid}", query_parms, headers
      @uri = entity["#{attr}_url"]
    end
  end

  shared_examples "inlined_relations" do |attr, depth|
    attr = attr.to_s

    it "should return a relative uri in the #{attr}_url field" do
      @uri.should_not be_nil
    end

    if depth.nil? || depth == 0
      it "should not return a #{attr} field" do
        entity.should_not have_key(attr)
      end
    else
      it "should return a #{attr} field" do
        entity.should have_key(attr)
      end
    end
  end

  shared_examples "get to_many attr url" do |opts, attr, make|
    describe "GET on the #{attr}_url" do
      describe "with no associated #{attr}" do
        before do
          obj.send("remove_all_#{attr}")
          get @uri, {}, headers
        end

        it "should return 200" do
          last_response.status.should == 200
        end

        it "should return total_results => 0" do
          decoded_response["total_results"].should == 0
        end

        it "should return prev_url => nil" do
          decoded_response.should have_key("prev_url")
          decoded_response["prev_url"].should be_nil
        end

        it "should return next_url => nil" do
          decoded_response["next_url"].should be_nil
        end

        it "should return resources => []" do
          decoded_response["resources"].should == []
        end
      end

      describe "with 2 associated #{attr}" do
        before do
          obj.send("remove_all_#{attr}")
          @child1 = make.call(obj)
          @child2 = make.call(obj)

          obj.send(add_method, @child1)
          obj.send(add_method, @child2)
          obj.save

          get @uri, {}, headers
        end

        it "should return 200" do
          last_response.status.should == 200
        end

        it "should return total_results => 2" do
          decoded_response["total_results"].should == 2
        end

        it "should return prev_url => nil" do
          decoded_response.should have_key("prev_url")
          decoded_response["prev_url"].should be_nil
        end

        it "should return next_url => nil" do
          decoded_response["next_url"].should be_nil
        end

        it "should return resources => [child1, child2]" do
          os = VCAP::CloudController::RestController::PreloadedObjectSerializer.new
          ar = opts[:model].association_reflection(attr)
          child_controller = VCAP::CloudController.controller_from_model_name(ar.associated_class.name)

          c1 = normalize_attributes(os.serialize(child_controller, @child1, {}))
          c2 = normalize_attributes(os.serialize(child_controller, @child2, {}))

          decoded_response["resources"].size.should == 2
          decoded_response["resources"].should =~ [c1, c2]
        end
      end
    end
  end

  shared_examples "collection operations" do |opts|
    describe "collections" do
      describe "modifying collections" do
        describe "one_to_many" do
          opts[:one_to_many_collection_ids].each do |attr, make|
            describe "#{attr}" do
              include_context "collections", opts, attr, make
              before do
                @child1 = make.call(obj)
              end

              describe "PUT #{opts[:path]}/:guid with #{attr} in the request body" do
                it "should return 200" do
                  do_write(:put, [@child1], 201, [@child1])
                end
              end
            end
          end
        end

        describe "many_to_many" do
          opts[:many_to_many_collection_ids].each do |attr, make|
            describe "#{attr}" do
              include_context "collections", opts, attr, make
              child_name  = attr.to_s.chomp("_guids")
              path = "#{opts[:path]}/:guid"

              before do
                @child1 = make.call(obj)
                @child2 = make.call(obj)
                @child3 = make.call(obj)
              end

              describe "POST #{path} with only #{attr} in the request body" do
                before do
                  do_write(:post, [@child1], 404, [])
                end

                it "should return 404" do
                  last_response.status.should == 404
                end

                it_behaves_like "a vcap rest error response"
              end

              describe "PUT #{path} with only #{attr} in body" do
                it "[:valid_id] should add a #{attr.to_s.singularize}" do
                  do_write(:put, [@child1], 201, [@child1])
                end

                it "[:valid_id1, :valid_id2] should add multiple #{attr}" do
                  do_write(:put, [@child1, @child2], 201, [@child1, @child2])
                end

                it "[:valid_id1, :valid_id2] should replace existing #{attr}" do
                  obj.send(add_method, @child1)
                  obj.send(get_method).should include(@child1)
                  do_write(:put, [@child2, @child3], 201, [@child2, @child3])
                  obj.send(get_method).should_not include(@child1)
                end

                it "[] should remove all #{child_name}s" do
                  obj.send(add_method, @child1)
                  obj.send(get_method).should include(@child1)
                  do_write(:put, [], 201, [])
                  obj.send(get_method).should_not include(@child1)
                end

                it "[:invalid_id] should return 400" do
                  obj.send(add_method, @child1)
                  obj.send(get_method).should include(@child1)
                  do_write(:put, [], 201, [])
                  obj.send(get_method).should_not include(@child1)
                end
              end
            end
          end
        end
      end

      describe "reading collections" do
        describe "many_to_many, one_to_many" do
          # this is basically the read api, so we'll do most of the
          # detailed read testing there

          to_many_attrs = opts[:many_to_many_collection_ids].merge(opts[:one_to_many_collection_ids])
          to_many_attrs.each do |attr, make|
            path = "#{opts[:path]}/:guid"

            [nil, 0, 1].each do |inline_relations_depth|
              desc = ControllerHelpers::description_for_inline_depth(inline_relations_depth)
              describe "GET #{path}#{desc}" do
                include_context "collections", opts, attr, make
                include_context "inlined_relations_context", opts, attr, make, inline_relations_depth
                include_examples "inlined_relations", attr, inline_relations_depth
                include_examples "get to_many attr url", opts, attr, make
              end
            end

            describe "with 3 associated #{attr}" do
              depth = 1
              pagination = 2
              desc = ControllerHelpers::description_for_inline_depth(depth, pagination)
              describe "GET #{path}#{desc}" do
                include_context "collections", opts, attr, make

                let(:query_params) {query_params_for_inline_depth(depth, pagination)}

                before do
                  obj.send("remove_all_#{attr}")
                  3.times do
                    child = make.call(obj)
                    obj.refresh
                    obj.send(add_method, child)
                  end

                  get "#{opts[:path]}/#{obj.guid}", query_params, headers
                  @uri = entity["#{attr}_url"]
                end

                # we want to make sure to only limit the assocation that
                # has too many results yet still inline the others
                context "when inline depth = 0" do
                  let(:query_params) { {} }
                  include_examples "inlined_relations", attr
                end
                (to_many_attrs.keys - [attr]).each do |other_attr|
                  include_examples "inlined_relations", other_attr, depth
                end

                describe "GET on the #{attr}_url" do
                  before do
                    get @uri, query_params, headers

                    @raw_guids = obj.send(get_method).sort do |a, b|
                      a[:id] <=> b[:id]
                    end.map { |o| o.guid }
                  end

                  it "should return 200" do
                    last_response.status.should == 200
                  end

                  it "should return total_results => 3" do
                    decoded_response["total_results"].should == 3
                  end

                  it "should return prev_url => nil" do
                    decoded_response.should have_key("prev_url")
                    decoded_response["prev_url"].should be_nil
                  end

                  it "should return next_url" do
                    decoded_response.should have_key("next_url")
                    next_url = decoded_response["next_url"]
                    next_url.should match /#{@uri}\?/
                    next_url.should include("page=2&results-per-page=2")
                  end

                  it "should return the first page of resources" do
                    decoded_response["resources"].count.should == 2
                    api_guids = decoded_response["resources"].map do |v|
                      v["metadata"]["guid"]
                    end

                    api_guids.should == @raw_guids[0..1]
                  end

                  it "should return the next 1 resource when fetching next_url" do
                    query_parms = query_params_for_inline_depth(depth)
                    get decoded_response["next_url"], query_parms, headers
                    last_response.status.should == 200
                    decoded_response["resources"].count.should == 1
                    guid = decoded_response["resources"][0]["metadata"]["guid"]
                    guid.should == @raw_guids[2]
                  end
                end
              end
            end
          end
        end

        describe "many_to_one" do
          opts[:many_to_one_collection_ids].each do |attr, make|
            path = "#{opts[:path]}/:guid"

            [nil, 0, 1].each do |inline_relations_depth|
              desc = ControllerHelpers::description_for_inline_depth(inline_relations_depth)
              describe "GET #{path}#{desc}" do
                include_context "collections", opts, attr, make

                before do
                  obj.send("#{attr}=", make.call(obj)) unless obj.send(attr)
                  obj.save
                end

                include_context "inlined_relations_context", opts, attr, make, inline_relations_depth
                include_examples "inlined_relations", attr, inline_relations_depth

                it "should return a #{attr}_guid field" do
                  entity.should have_key("#{attr}_guid")
                end

                # this is basically the read api, so we'll do most of the
                # detailed read testing there
                desc = ControllerHelpers::description_for_inline_depth(inline_relations_depth)
                describe "GET on the #{attr}_url" do
                  before do
                    get @uri, {}, headers
                  end

                  it "should return 200" do
                    last_response.status.should == 200
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
