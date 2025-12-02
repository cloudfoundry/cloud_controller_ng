# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

# 初始化OSS client
Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
conf_file = '~/.oss.yml'
conf = YAML.load(File.read(File.expand_path(conf_file)))
client = Aliyun::OSS::Client.new(
  :endpoint => conf['endpoint'],
  :cname => conf['cname'],
  :access_key_id => conf['access_key_id'],
  :access_key_secret => conf['access_key_secret'])
bucket = client.get_bucket(conf['bucket'])

# 辅助打印函数
def demo(msg)
  puts "######### #{msg} ########"
  puts
  yield
  puts "-------------------------"
  puts
end

# 列出当前所有的bucket
demo "List all buckets" do
  buckets = client.list_buckets
  buckets.each{ |b| puts "Bucket: #{b.name}"}
end

# 创建bucket，如果同名的bucket已经存在，则创建会失败
demo "Create bucket" do
  begin
    bucket_name = 't-foo-bar'
    client.create_bucket(bucket_name, :location => 'oss-cn-hangzhou')
    puts "Create bucket success: #{bucket_name}"
  rescue => e
    puts "Create bucket failed: #{bucket_name}, #{e.message}"
  end
end

# 向bucket中添加5个空的object:
# foo/obj1, foo/bar/obj1, foo/bar/obj2, foo/xxx/obj1

demo "Put objects before list" do
  bucket.put_object('foo/obj1')
  bucket.put_object('foo/bar/obj1')
  bucket.put_object('foo/bar/obj2')
  bucket.put_object('foo/xxx/obj1')
  bucket.put_object('中国の')
end

# list bucket下所有objects
demo "List first 10 objects" do
  objects = bucket.list_objects

  objects.take(10).each do |o|
    puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
  end
end

# list bucket下所有前缀为foo/bar/的object
demo "List first 10 objects with prefix 'foo/bar/'" do
  objects = bucket.list_objects(:prefix => 'foo/bar/')

  objects.take(10).each do |o|
    puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
  end
end

# 获取object的common prefix，common prefix是指bucket下所有object（也可
# 以指定特定的前缀）的公共前缀，这在object数量巨多的时候很有用，例如有
# 如下的object：
#     /foo/bar/obj1
#     /foo/bar/obj2
#     ...
#     /foo/bar/obj9999999
#     /foo/xx/
# 指定foo/为prefix，/为delimiter，则返回的common prefix为
# /foo/bar/, /foo/xxx/
# 这可以表示/foo/目录下的子目录。如果没有common prefix，你可能要遍历所
# 有的object来找公共的前缀

demo "List first 10 objects/common prefixes" do
  objects = bucket.list_objects(:prefix => 'foo/', :delimiter => '/')

  objects.take(10).each do |o|
    if o.is_a?(Aliyun::OSS::Object)
      puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
    else
      puts "Common prefix: #{o}"
    end
  end
end

# 获取/设置Bucket属性: ACL, Logging, Referer, Website, LifeCycle, CORS
demo "Get/Set bucket properties: ACL/Logging/Referer/Website/Lifecycle/CORS" do
  puts "Bucket acl before: #{bucket.acl}"
  bucket.acl = Aliyun::OSS::ACL::PUBLIC_READ
  puts "Bucket acl now: #{bucket.acl}"
  puts

  puts "Bucket logging before: #{bucket.logging.to_s}"
  bucket.logging = Aliyun::OSS::BucketLogging.new(
    :enable => true, :target_bucket => conf['bucket'], :target_prefix => 'foo/')
  puts "Bucket logging now: #{bucket.logging.to_s}"
  puts

  puts "Bucket referer before: #{bucket.referer.to_s}"
  bucket.referer = Aliyun::OSS::BucketReferer.new(
    :allow_empty => true, :whitelist => ['baidu.com', 'aliyun.com'])
  puts "Bucket referer now: #{bucket.referer.to_s}"
  puts

  puts "Bucket website before: #{bucket.website.to_s}"
  bucket.website = Aliyun::OSS::BucketWebsite.new(
    :enable => true, :index => 'default.html', :error => 'error.html')
  puts "Bucket website now: #{bucket.website.to_s}"
  puts

  puts "Bucket lifecycle before: #{bucket.lifecycle.map(&:to_s)}"
  bucket.lifecycle = [
    Aliyun::OSS::LifeCycleRule.new(
    :id => 'rule1', :enable => true, :prefix => 'foo/', :expiry => 1),
    Aliyun::OSS::LifeCycleRule.new(
      :id => 'rule2', :enable => false, :prefix => 'bar/', :expiry => Date.new(2016, 1, 1))
  ]
  puts "Bucket lifecycle now: #{bucket.lifecycle.map(&:to_s)}"
  puts

  puts "Bucket cors before: #{bucket.cors.map(&:to_s)}"
  bucket.cors = [
    Aliyun::OSS::CORSRule.new(
    :allowed_origins => ['aliyun.com', 'http://www.taobao.com'],
    :allowed_methods => ['PUT', 'POST', 'GET'],
    :allowed_headers => ['Authorization'],
    :expose_headers => ['x-oss-test'],
    :max_age_seconds => 100)
  ]
  puts "Bucket cors now: #{bucket.cors.map(&:to_s)}"
  puts
end
