# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  def self.description_for_inline_depth(depth)
    if depth
      "?inline-relations-depth=#{depth}"
    else
      ""
    end
  end

  def query_params_for_inline_depth(depth)
    if depth
      { "inline-relations-depth" => depth }
    else
      { }
    end
  end

  shared_context "collections" do |opts, attr, make|
    before do
      @opts = opts
      @attr = attr

      @child_name  = attr.to_s.singularize

      @add_method  = "add_#{@child_name}"
      @get_method  = "#{@child_name}s"

      @obj = opts[:model].make
      @other_obj = opts[:model].make

      @child1 = make.call(@obj)
      @child2 = make.call(@obj)
      @child3 = make.call(@obj)

      user = VCAP::CloudController::Models::User.make(:admin => true)
      @headers = json_headers(headers_for(user))
    end

    def do_write(verb, children, expected_result, expected_children)
      body = Yajl::Encoder.encode({"#{@child_name}_guids" => children.map { |c| c[:guid] }})
      send(verb, "#{@opts[:path]}/#{@obj.guid}", body, @headers)
      last_response.status.should == expected_result

      @obj.refresh
      @obj.send(@get_method).length.should == expected_children.length
      expected_children.each { |c| @obj.send(@get_method).should include(c.refresh) }
    end
  end

  shared_context "inlined_relations_context" do |opts, attr, make, depth|
    before do
      query_parms = query_params_for_inline_depth(depth)
      get "#{opts[:path]}/#{@obj.guid}", query_parms, @headers
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
          get @uri, {}, @headers
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
          @obj.send(@add_method, @child1)
          @obj.send(@add_method, @child2)
          @obj.save

          get @uri, {}, @headers
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
          os = VCAP::CloudController::RestController::ObjectSerialization
          ar = opts[:model].association_reflection(attr)
          child_controller = VCAP::CloudController.controller_from_model_name(ar.associated_class.name)

          c1 = os.to_hash(child_controller, @child1, {})
          c2 = os.to_hash(child_controller, @child2, {})

          [c1, c2].each do |c|
            m = c["metadata"]
            m["created_at"] = m["created_at"].to_s
            m["updated_at"] = m["updated_at"].to_s if m["updated_at"]
          end

          decoded_response["resources"].should == [c1, c2]
        end
      end
    end
  end

  shared_examples "collection operations" do |opts|
    describe "collections" do
      # FIXME: this needs to be re-enabled.. *BUT* needs to be split
      # into read/write portions that can be turned on independently.
      # Not all models currently have both import and export on their
      # on_to_many relations, which this currently assumes.
      #
      # describe "modifying one_to_many collections" do
      #   opts[:one_to_many_collection_ids].each do |attr, make|
      #     describe "#{attr}" do
      #       include_context "collections", opts, attr, make
      #       child_name  = attr.to_s

      #       describe "PUT #{opts[:path]}/:guid with #{attr} in the request body" do
      #         it "should return 200" do
      #           do_write(:put, [@child1], 201, [@child1])
      #         end
      #       end
      #     end
      #   end
      # end

      describe "modifying many_to_many collections" do
        opts[:many_to_many_collection_ids].each do |attr, make|
          describe "#{attr}" do
            include_context "collections", opts, attr, make
            child_name  = attr.to_s.chomp("_guids")
            path = "#{opts[:path]}/:guid"

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
                @obj.send(@add_method, @child1)
                @obj.send(@get_method).should include(@child1)
                do_write(:put, [@child2, @child3], 201, [@child2, @child3])
                @obj.send(@get_method).should_not include(@child1)
              end

              it "[] should remove all #{child_name}s" do
                @obj.send(@add_method, @child1)
                @obj.send(@get_method).should include(@child1)
                do_write(:put, [], 201, [])
                @obj.send(@get_method).should_not include(@child1)
              end

              it "[:invalid_id] should return 400" do
                @obj.send(@add_method, @child1)
                @obj.send(@get_method).should include(@child1)
                do_write(:put, [], 201, [])
                @obj.send(@get_method).should_not include(@child1)
              end

              # FIXME: add an error id in the middle of an array test

              # FIXME: other bad json input tests
            end
          end
        end
      end

      describe "reading collections" do
        describe "many_to_one" do
          opts[:many_to_one_collection_ids].each do |attr, make|
            path = "#{opts[:path]}/:guid"

            [nil, 0, 1].each do |inline_relations_depth|
              desc = VCAP::CloudController::ApiSpecHelper::description_for_inline_depth(inline_relations_depth)
              describe "GET #{path}#{desc}" do
                include_context "collections", opts, attr, make

                before do
                  @obj.send("#{attr}=", make.call(@obj)) unless @obj.send(attr)
                  @obj.save
                end

                include_context "inlined_relations_context", opts, attr, make, inline_relations_depth
                include_examples "inlined_relations", attr, inline_relations_depth

                it "should return a #{attr}_guid field" do
                  entity.should have_key("#{attr}_guid")
                end

                # this is basically the read api, so we'll do most of the
                # detailed read testing there
                desc = VCAP::CloudController::ApiSpecHelper::description_for_inline_depth(inline_relations_depth)
                describe "GET on the #{attr}_url" do
                  before do
                    get @uri, {}, @headers
                  end

                  it "should return 200" do
                    last_response.status.should == 200
                  end
                end
              end
            end
          end
        end

        describe "n_to_many" do
          # this is basically the read api, so we'll do most of the
          # detailed read testing there

          to_many_attrs = opts[:many_to_many_collection_ids].merge(opts[:one_to_many_collection_ids])
          to_many_attrs.each do |attr, make|
            path = "#{opts[:path]}/:guid"

            [nil, 0, 1].each do |inline_relations_depth|
              desc = VCAP::CloudController::ApiSpecHelper::description_for_inline_depth(inline_relations_depth)
              describe "GET #{path}#{desc}" do
                include_context "collections", opts, attr, make
                include_context "inlined_relations_context", opts, attr, make, inline_relations_depth
                include_examples "inlined_relations", attr, inline_relations_depth
                include_examples "get to_many attr url", opts, attr, make
              end
            end

            describe "with 51 associated #{attr}" do
              depth = 1
              desc = VCAP::CloudController::ApiSpecHelper::description_for_inline_depth(depth)
              describe "GET #{path}#{desc}" do
                include_context "collections", opts, attr, make

                before do
                  51.times do
                    child = make.call(@obj)
                    @obj.refresh
                    @obj.send(@add_method, child)
                  end

                  query_parms = query_params_for_inline_depth(depth)
                  get "#{opts[:path]}/#{@obj.guid}", query_parms, @headers
                  @uri = entity["#{attr}_url"]
                end

                # we want to make sure to only limit the assocation that
                # has too many results yet still inline the others
                include_examples "inlined_relations", attr
                (to_many_attrs.keys - [attr]).each do |other_attr|
                  include_examples "inlined_relations", other_attr, 1
                end

                describe "GET on the #{attr}_url" do
                  before do
                    get @uri, {}, @headers
                  end

                  it "should return 200" do
                    last_response.status.should == 200
                  end

                  it "should return total_results => 51" do
                    decoded_response["total_results"].should == 51
                  end

                  it "should return prev_url => nil" do
                    decoded_response.should have_key("prev_url")
                    decoded_response["prev_url"].should be_nil
                  end

                  it "should return next_url" do
                    decoded_response.should have_key("next_url")
                    next_url = decoded_response["next_url"]
                    uri = @uri.gsub("?", "\\?")
                    next_url.should match /#{uri}&page=2&results-per-page=50/
                  end

                  it "should return resources => []" do
                    decoded_response["resources"].count.should == 50
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
