# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # OSS服务的客户端，用于获取bucket列表，创建/删除bucket。Object相关
    # 的操作请使用{OSS::Bucket}。
    # @example 创建Client
    #   endpoint = 'oss-cn-hangzhou.aliyuncs.com'
    #   client = Client.new(
    #     :endpoint => endpoint,
    #     :access_key_id => 'access_key_id',
    #     :access_key_secret => 'access_key_secret')
    #   buckets = client.list_buckets
    #   client.create_bucket('my-bucket')
    #   client.delete_bucket('my-bucket')
    #   bucket = client.get_bucket('my-bucket')
    class Client

      # 构造OSS client，用于操作buckets。
      # @param opts [Hash] 构造Client时的参数选项
      # @option opts [String] :endpoint [必填]OSS服务的地址，可以是以
      #  oss-cn-hangzhou.aliyuncs.com的标准域名，也可以是用户绑定的域名
      # @option opts [String] :access_key_id [可选]用户的ACCESS KEY ID，
      #  如果不填则会尝试匿名访问
      # @option opts [String] :access_key_secret [可选]用户的ACCESS
      #  KEY SECRET，如果不填则会尝试匿名访问
      # @option opts [Boolean] :cname [可选] 指定endpoint是否是用户绑
      #  定的域名
      # @option opts [Boolean] :upload_crc_enable [可选]指定上传处理
      #  是否开启CRC校验，默认为开启(true)
      # @option opts [Boolean] :download_crc_enable [可选]指定下载处理
      #  是否开启CRC校验，默认为不开启(false)
      # @option opts [String] :sts_token [可选] 指定STS的
      #  SecurityToken，如果指定，则使用STS授权访问
      # @option opts [Integer] :open_timeout [可选] 指定建立连接的超时
      #  时间，默认为10秒
      # @option opts [Integer] :read_timeout [可选] 指定等待响应的超时
      #  时间，默认为120秒
      # @example 标准endpoint
      #   oss-cn-hangzhou.aliyuncs.com
      #   oss-cn-beijing.aliyuncs.com
      # @example 用户绑定的域名
      #   my-domain.com
      #   foo.bar.com
      def initialize(opts)
        fail ClientError, "Endpoint must be provided" unless opts[:endpoint]

        @config = Config.new(opts)
        @protocol = Protocol.new(@config)
      end

      # 列出当前所有的bucket
      # @param opts [Hash] 查询选项
      # @option opts [String] :prefix 如果设置，则只返回以它为前缀的bucket
      # @option opts [String] :marker 如果设置，则只返回名字在它之后
      #  （字典序，不包含marker）的bucket
      # @return [Enumerator<Bucket>] Bucket的迭代器
      def list_buckets(opts = {})
        if @config.cname
          fail ClientError, "Cannot list buckets for a CNAME endpoint."
        end

        Iterator::Buckets.new(@protocol, opts).to_enum
      end

      # 创建一个bucket
      # @param name [String] Bucket名字
      # @param opts [Hash] 创建Bucket的属性（可选）
      # @option opts [:location] [String] 指定bucket所在的区域，默认为oss-cn-hangzhou
      def create_bucket(name, opts = {})
        Util.ensure_bucket_name_valid(name)
        @protocol.create_bucket(name, opts)
      end

      # 删除一个bucket
      # @param name [String] Bucket名字
      # @note 如果要删除的Bucket不为空（包含有object），则删除会失败
      def delete_bucket(name)
        Util.ensure_bucket_name_valid(name)
        @protocol.delete_bucket(name)
      end

      # 判断一个bucket是否存在
      # @param name [String] Bucket名字
      # @return [Boolean] 如果Bucket存在则返回true，否则返回false
      def bucket_exists?(name)
        Util.ensure_bucket_name_valid(name)
        exist = false

        begin
          @protocol.get_bucket_acl(name)
          exist = true
        rescue ServerError => e
          raise unless e.http_code == 404
        end

        exist
      end

      alias :bucket_exist? :bucket_exists?

      # 获取一个Bucket对象，用于操作bucket中的objects。
      # @param name [String] Bucket名字
      # @return [Bucket] Bucket对象
      def get_bucket(name)
        Util.ensure_bucket_name_valid(name)
        Bucket.new({:name => name}, @protocol)
      end

    end # Client
  end # OSS
end # Aliyun
