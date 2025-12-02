# frozen_string_literal: true

module Fog
  module Aliyun
    class Storage
      class Real
        # Put details for object
        #
        # ==== Parameters
        # * bucket_name<~String> - Name of bucket to look for
        # * object_name<~String> - Object of object to look for
        # * data<~File>
        # * options<~Hash>
        #
        def put_object(bucket_name, object_name, data, options = {})
          if data.is_a? ::File
            @oss_protocol.put_object(bucket_name, object_name, options)do |sw|
              while line = data.read(16*1024)
                sw.write(line)
              end
            end
          else
            content=StringIO.new(data.dup)
            @oss_protocol.put_object(bucket_name, object_name, options)do |sw|
              while line=content.read(16*1024)
                sw.write(line)
              end
            end
            content.close
          end
        end
      end
    end
  end
end
