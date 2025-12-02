# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/sts'
require 'aliyun/oss'

# 初始化OSS client
Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
conf_file = '~/.sts.yml'
conf = YAML.load(File.read(File.expand_path(conf_file)))

# 辅助打印函数
def demo(msg)
  puts "######### #{msg} ########"
  puts
  yield
  puts "-------------------------"
  puts
end

demo "Using STS" do
  sts = Aliyun::STS::Client.new(
    :access_key_id => conf['access_key_id'],
    :access_key_secret => conf['access_key_secret'])

  token = sts.assume_role(
    'acs:ram::52352:role/aliyunosstokengeneratorrole', 'app-1')

  client = Aliyun::OSS::Client.new(
    :endpoint => 'http://oss-cn-hangzhou.aliyuncs.com',
    :sts_token => token.security_token,
    :access_key_id => token.access_key_id,
    :access_key_secret => token.access_key_secret)

  unless client.bucket_exists?('bucket-for-sts-test')
    client.create_bucket('bucket-for-sts-test')
  end

  bucket = client.get_bucket('bucket-for-sts-test')

  bucket.put_object('hello') { |s| s << 'hello' }
  bucket.put_object('world') { |s| s << 'world' }

  bucket.list_objects.take(10).each do |obj|
    puts "Object: #{obj.key}, size: #{obj.size}"
  end
end
