require 'nokogiri'
module Fog
  module Aliyun
    class Storage
      class Real

        # Get location constraint for an OSS bucket
        #
        # @param bucket_name [String] name of bucket to get location constraint for
        #
        # @see https://help.aliyun.com/document_detail/31967.html
        #
        # note: The OSS Ruby sdk does not support get_bucket_location and there needs to parse response

        def get_bucket_location(bucket_name)
          data = @oss_http.get({:bucket => bucket_name, :sub_res => { 'location' => nil} }, {})
          doc = parse_xml(data.body)
          doc.at_css("LocationConstraint").text
        end

        private

        def parse_xml(content)
          doc = Nokogiri::XML(content) do |config|
            config.options |= Nokogiri::XML::ParseOptions::NOBLANKS
          end

          doc
        end
      end
    end
  end
end
