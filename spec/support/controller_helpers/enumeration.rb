module ControllerHelpers
  shared_examples "paginated enumeration request" do |base_path, page, page_size, total_results, page_results|
    page_count = (total_results / page_size.to_f).ceil
    path = base_path =~ /\?/ ? "#{base_path}&" : "#{base_path}?"

    qp = []
    if page
      qp << "page=#{page}&"
    else
      page = 1
    end
    qp << "results-per-page=#{page_size}"

    path = "#{path}#{qp.join("&")}"

    describe "GET #{path}" do
      before { get path, {}, json_headers(admin_headers) }

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
          expected_qp = "order-direction=asc&page=#{prev_page}&results-per-page=#{page_size}"
          expected_url = if base_path =~ /\?/
                           /#{base_path.sub("?", "\\?")}&#{expected_qp}/
                         else
                           /#{base_path}\?#{expected_qp}/
                         end

          prev_url = decoded_response["prev_url"]
          prev_url.should match expected_url
        end
      else
        it "should return prev_url of nil" do
          decoded_response["prev_url"].should be_nil
        end
      end

      next_page = page < page_count ? (page + 1) : nil
      if next_page
        it "should return next_url to page #{next_page}" do
          expected_qp = "order-direction=asc&page=#{next_page}&results-per-page=#{page_size}"
          expected_url = if base_path =~ /\?/
                           /#{base_path.sub("?", "\\?")}&#{expected_qp}/
                         else
                           /#{base_path}\?#{expected_qp}/
                         end
          next_url = decoded_response["next_url"]
          next_url.should match expected_url
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
        before do
          # force creation of the admin user used in the headers
          admin_headers
          num_to_create = 8 - opts[:model].count
          num_to_create.times do
            opts[:model].make
          end
        end

        context "without inlined relations" do
          include_examples "paginated enumeration request", opts[:path], nil, 3, 8, 3
          include_examples "paginated enumeration request", opts[:path], 1, 3, 8, 3
          include_examples "paginated enumeration request", opts[:path], 2, 3, 8, 3
          include_examples "paginated enumeration request", opts[:path], 3, 3, 8, 2
        end

        context "with inlined relations" do
          path = "#{opts[:path]}?inline-relations-depth=1"
          include_examples "paginated enumeration request", path, nil, 3, 8, 3
          include_examples "paginated enumeration request", path, 1, 3, 8, 3
          include_examples "paginated enumeration request", path, 2, 3, 8, 3
          include_examples "paginated enumeration request", path, 3, 3, 8, 2
        end
      end
    end
  end
end
