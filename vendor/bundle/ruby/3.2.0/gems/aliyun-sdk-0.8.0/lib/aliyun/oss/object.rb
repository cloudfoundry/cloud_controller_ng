# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # Object表示OSS存储的一个对象
    #
    class Object < Common::Struct::Base

      attrs :key, :type, :size, :etag, :metas, :last_modified, :headers

    end # Object
  end # OSS
end # Aliyun
