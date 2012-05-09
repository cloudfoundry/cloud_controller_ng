# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
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
      headers = {}
      headers["HTTP_AUTHORIZATION"] = user.id
      @headers = json_headers(headers)
    end

    def do_write(verb, children, expected_result, expected_children)
      body = Yajl::Encoder.encode({"#{@child_name}_ids" => children.map { |c| c[:id] }})
      send(verb, "#{@opts[:path]}/#{@obj.id}", body, @headers)
      last_response.status.should == expected_result

      @obj.refresh
      @obj.send(@get_method).length.should == expected_children.length
      expected_children.each { |c| @obj.send(@get_method).should include(c) }
    end
  end

  shared_examples "collection operations" do |opts|
    describe "collections" do
      describe "modifying one_to_many collections" do
        opts[:one_to_many_collection_ids].each do |attr, make|
          describe "#{attr}" do
            include_context "collections", opts, attr, make
            child_name  = attr.to_s

            describe "PUT #{opts[:path]}/:id with #{attr} in the request body" do
              # FIXME: right now, we ignore invalid input
              it "should return 200 but have no effect (FIXME: extra params on a PUT are currently ignored)" do
                do_write(:put, [@child1], 201, [])
              end
            end
          end
        end
      end

      describe "modifying many_to_many collections" do
        opts[:many_to_many_collection_ids].each do |attr, make|
          describe "#{attr}" do
            include_context "collections", opts, attr, make
            child_name  = attr.to_s.chomp("_ids")
            path = "#{opts[:path]}/:id"

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
        include VCAP::CloudController::RestController

        opts[:many_to_many_collection_ids].merge(opts[:one_to_many_collection_ids]).each do |attr, make|
          path = "#{opts[:path]}/:id"

          describe "GET #{path} and extract #{attr}_url" do
            include_context "collections", opts, attr, make

            before do
              get "#{opts[:path]}/#{@obj.id}", {}, @headers
              @uri = entity["#{attr}_url"]
            end

            it "should return a relative uri in the #{attr}_url field" do
              @uri.should_not be_nil
            end

            describe "gets on the #{attr}_url with no associated #{attr}" do
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

            describe "gets on the #{attr}_url with 2 associated #{attr}" do
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

              # TODO: these are both nil for now because we aren't doing
              # full pagination yet
              it "should return prev_url => nil" do
                decoded_response.should have_key("prev_url")
                decoded_response["prev_url"].should be_nil
              end

              it "should return next_url => nil" do
                decoded_response["next_url"].should be_nil
              end

              it "should return resources => [child1, child2]" do
                os = VCAP::CloudController::RestController::ObjectSerialization
                name ="#{attr.to_s.singularize.camelize}"
                child_controller = VCAP::CloudController.const_get(name)

                c1 = os.to_hash(child_controller, @child1)
                c2 = os.to_hash(child_controller, @child2)

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
      end
    end
  end
end
