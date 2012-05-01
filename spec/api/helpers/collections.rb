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
      headers['HTTP_AUTHORIZATION'] = user.email
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

            # FIXME: make like the many_to_many tests below
            # FIXME: also.. the API changed.. make this work the new way
            #
            # describe "DELETE #{opts[:path]}/:id/#{attr.to_s.singularize}_ids/:non_existant_child_id" do
            #   before do
            #     @obj.send(@add_method, @child1)
            #     @obj.send(@add_method, @child2)
            #     delete "#{opts[:path]}/#{@obj.id}/#{attr.to_s.singularize}_ids/999999", {}, @headers
            #   end

            #   # these should proably return errors
            #   it "should return 204" do
            #     last_response.status.should == 204
            #   end

            #   # see above
            #   # it_behaves_like "a vcap rest error response"

            #   it "should have no effect" do
            #     @obj.refresh
            #     @obj.send(@get_method).length.should == 2
            #     @obj.send(@get_method).should include(@child1)
            #     @obj.send(@get_method).should include(@child2)
            #   end
            # end
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
              it "[:valid_id] should add a #{attr.to_s.chomp('s')}" do
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

            # FIXME: have coverage over the new way?
            # describe "DELETE #{path}/#{attr.to_s.singularize}_ids" do
            #   it "DELETE ../:id should remove a single #{attr}" do
            #     @obj.send(@add_method, @child1)
            #     @obj.send(@add_method, @child2)

            #     delete "#{opts[:path]}/#{@obj.id}/#{attr.to_s.singularize}_ids/#{@child1.id}", {}, @headers

            #     last_response.status.should == 204

            #     @obj.refresh
            #     @obj.send(@get_method).length.should == 1
            #     @obj.send(@get_method).should_not include(@child1)
            #     @obj.send(@get_method).should include(@child2)
            #   end

            #   it "DELETE ../:non_existant should return ok" do
            #     @obj.send(@add_method, @child1)
            #     @obj.send(@add_method, @child2)

            #     delete "#{opts[:path]}/#{@obj.id}/#{attr.to_s.singularize}_ids/#{@child3.id}", {}, @headers

            #     last_response.status.should == 204

            #     @obj.refresh
            #     @obj.send(@get_method).length.should == 2
            #     @obj.send(@get_method).should include(@child1)
            #     @obj.send(@get_method).should include(@child2)
            #   end
            # end
          end
        end
      end

      describe "reading collections" do
        opts[:many_to_many_collection_ids].merge(opts[:one_to_many_collection_ids]).each do |attr, make|
          path = "#{opts[:path]}/:id"

          describe "GET #{path}/#{attr}_url" do
            include_context "collections", opts, attr, make

            it "should return a https url" do
              # FIXME
              pending
            end


            it "gets on the url should return an empty list where there are no #{attr}" do
              pending
              # get "#{opts[:path]}/#{@obj.id}/#{attr}", {}, @headers
              # last_response.status.should == 200
              # expected = { attr.to_s => [] }
              # Yajl::Parser.parse(last_response.body).should == expected
            end

            it "gets on the url should return multiple #{attr}" do
              pending
              # @obj.send(@add_method, @child1)
              # @obj.send(@add_method, @child2)
              # @obj.save
              # get "#{opts[:path]}/#{@obj.id}/#{attr}", {}, @headers
              # last_response.status.should == 200
              # expected = { attr.to_s => [@child1.id, @child2.id] }
              # Yajl::Parser.parse(last_response.body).should == expected
            end
          end
        end
      end
    end
  end
end
