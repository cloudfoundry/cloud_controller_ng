# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  shared_examples "paginated enumeration request" do |base_path, page, page_size, total_results, page_results|
    page_count = (total_results / page_size.to_f).ceil

    path = "#{base_path}?"
    if page
      path += "page=#{page}&"
    else
      page = 1
    end
    path += "results-per-page=#{page_size}"

    describe "GET #{path}" do
      before(:all) do
        get "#{path}", {}, json_headers(admin_headers)
      end

      it "should return 200" do
        last_response.status.should == 200
      end

      it "should return total_results => #{total_results}" do
        decoded_response["total_results"].should == total_results
      end

      it "should return a prev_url entry" do
        decoded_response.should have_key("prev_url")
      end

      it "should return a next_url entry" do
        decoded_response.should have_key("prev_url")
      end

      prev_page = page > 1 ? (page - 1) : nil
      if prev_page
        it "should return a prev_url to page #{prev_page}" do
          prev_url = decoded_response["prev_url"]
          prev_url.should match /#{base_path}\?page=#{prev_page}&results-per-page=#{page_size}/
        end
      else
        it "should return prev_url of nil" do
          decoded_response["prev_url"].should be_nil
        end
      end

      next_page = page < page_count ? (page + 1) : nil
      if next_page
        it "should return next_url to page #{next_page}" do
          next_url = decoded_response["next_url"]
          next_url.should match /#{base_path}\?page=#{next_page}&results-per-page=#{page_size}/
        end
      else
        it "should return next_url of nil" do
          decoded_response["next_page"].should be_nil
        end
      end

      it "should return #{page_results} resources" do
        decoded_response["resources"].count.should == page_results
      end
    end
  end

  shared_examples "enumerating objects" do |opts|
    describe "enumerating objects" do
      describe "with 8 objects" do
        before(:all) do
          reset_database
          # force creation of the admin user used in the headers
          admin_headers
          num_to_create = 8 - opts[:model].count
          num_to_create.times do
            opts[:model].make
          end
        end

        include_examples "paginated enumeration request", opts[:path], nil, 3, 8, 3
        include_examples "paginated enumeration request", opts[:path], 1, 3, 8, 3
        include_examples "paginated enumeration request", opts[:path], 2, 3, 8, 3
        include_examples "paginated enumeration request", opts[:path], 3, 3, 8, 2
      end
    end
  end
end
