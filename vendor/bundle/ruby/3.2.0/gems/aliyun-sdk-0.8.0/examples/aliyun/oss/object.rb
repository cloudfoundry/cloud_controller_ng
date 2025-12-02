# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

# 初始化OSS client
Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
conf_file = '~/.oss.yml'
conf = YAML.load(File.read(File.expand_path(conf_file)))
bucket = Aliyun::OSS::Client.new(
  :endpoint => conf['endpoint'],
  :cname => conf['cname'],
  :access_key_id => conf['access_key_id'],
  :access_key_secret => conf['access_key_secret']).get_bucket(conf['bucket'])

# 辅助打印函数
def demo(msg)
  puts "######### #{msg} ########"
  puts
  yield
  puts "-------------------------"
  puts
end

# 上传一个object
# 流式上传请参考：examples/streaming.rb
demo "Put object from input" do
  bucket.put_object('files/hello') do |content|
    content << 'hello world.'
  end
  puts "Put object: files/hello"
end

# 上传一个文件
# 断点续传请参考：examples/resumable_upload.rb
demo "Put object from local file" do
  File.open('/tmp/x', 'w'){ |f| f.write("hello world\n") }
  bucket.put_object('files/world', :file => '/tmp/x')
  puts "Put object: files/world"
end

# 创建一个Appendable object
demo "Create appendable object" do
size = bucket.get_object('files/appendable').size rescue 0
  bucket.append_object('files/appendable', size) do |content|
    content << 'hello appendable.'
  end
  puts "Append object: files/appendable"
end

# 向files/appendable中追加内容
# 首先要获取object当前的长度
demo "Append to object" do
  size = bucket.get_object('files/appendable').size
  bucket.append_object('files/appendable', size) do |content|
    content << 'again appendable.'
  end
  puts "Append object: files/appendable"
end

# 使用错误的position进行追加会失败
demo "Append with wrong pos" do
  begin
    bucket.append_object('files/appendable', 0) do |content|
      content << 'again appendable.'
    end
  rescue => e
    puts "Append failed: #{e.message}"
  end
end

# 向一个normal object中追加内容会失败
demo "Append to normal object(fail)" do
  begin
    bucket.append_object('files/hello', 0) do |content|
      content << 'hello appendable.'
    end
  rescue => e
    puts "Append object failed: #{e.message}"
  end
end

# 拷贝一个object
demo "Copy object" do
  bucket.copy_object('files/hello', 'files/copy')
  puts "Copy object files/hello => files/copy"
end

# 拷贝一个appendable object会失败
demo "Copy appendable object(fail)" do
  begin
    bucket.copy_object('files/appendable', 'files/copy')
  rescue => e
    puts "Copy object failed: #{e.message}"
  end
end

# 下载一个object：流式处理
# 流式下载请参考：examples/streaming.rb
demo "Get object: handle content" do
  total_size = 0
  bucket.get_object('files/hello') do |chunk|
    total_size += chunk.size
  end
  puts "Total size: #{total_size}"
end

# 下载一个object：下载到文件中
demo "Get object to local file" do
  bucket.get_object('files/hello', :file => '/tmp/hello')
  puts "Get object: files/hello => /tmp/hello"
end

# 删除一个object
demo "Delete object" do
  bucket.delete_object('files/world')
  puts "Delete object: files/world"
end

# 删除一个不存在的object返回OK
# 这意味着delete_object是幂等的，在删除失败的时候可以不断重试，直到成
# 功，成功意味着object已经不存在
demo "Delete a non-existent object(OK)" do
  bucket.delete_object('non-existent-object')
  puts "Delete object: non-existent-object"
end

# 设置Object metas
demo "Put objec with metas" do
  bucket.put_object(
    'files/hello',
    :metas => {'year' => '2015', 'people' => 'mary'}
  ) do |content|
    content << 'hello world.'
  end

  o = bucket.get_object('files/hello', :file => '/tmp/x')
  puts "Object metas: #{o.metas}"
end

# 修改Object metas
demo "Update object metas" do
  bucket.update_object_metas(
    'files/hello', {'year' => '2016', 'people' => 'jack'})
  o = bucket.get_object('files/hello')
  puts "Meta changed: #{o.metas}"
end

# 设置Object的ACL

demo "Set object ACL" do
  puts "Object acl before: #{bucket.get_object_acl('files/hello')}"
  bucket.set_object_acl('files/hello', Aliyun::OSS::ACL::PUBLIC_READ)
  puts "Object acl now: #{bucket.get_object_acl('files/hello')}"
end

# 指定条件get_object
demo "Get object with conditions" do
  o = bucket.get_object('files/hello')

  begin
    o = bucket.get_object(
      'files/hello',
      :condition => {:if_match_etag => o.etag + 'x'})
  rescue Aliyun::OSS::ServerError => e
    puts "Get object failed: #{e.message}"
  end

  begin
    o = bucket.get_object(
      'files/hello',
      :condition => {:if_unmodified_since => o.last_modified - 60})
  rescue Aliyun::OSS::ServerError => e
    puts "Get object failed: #{e.message}"
  end

  o = bucket.get_object(
    'files/hello',
    :condition => {:if_match_etag => o.etag, :if_unmodified_since => Time.now})
  puts "Get object: #{o.to_s}"
end
