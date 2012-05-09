# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  shared_examples "an authenticated CloudController API" do |model, actions|
    ['admin', 'regular', 'anonymous'].each do |user_type|
      context "as an #{user_type} user" do
        before do
          unless user_type == 'anonymous'
            user = VCAP::CloudController::Models::User.make(:admin => user_type == 'admin')
          end

          @headers = headers_for(user)
        end

        actions.each do |path, verb, admin_code, regular_code, anonymous_code, data|
          expected_code = eval("#{user_type}_code")
          specify "#{verb.upcase} #{path} should should return #{expected_code}" do
            path = eval('"' + path + '"')
            headers = @headers.dup
            if data
              data.each { |k, v| data[k] = eval('"' + v + '"') }
              data = Yajl::Encoder.encode(data)
              headers.merge!({ "CONTENT_TYPE" => "application/json"})
            end

            send(verb, path, data, headers)
            last_response.status.should == expected_code
          end
        end
      end
    end
  end
end
