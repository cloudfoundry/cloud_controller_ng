# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

##
# 一般来说用户在上传object和下载object时只需要指定文件名就可以满足需要：
# - 在上传的时候client会从指定的文件中读取数据上传到OSS
# - 在下载的时候client会把从OSS下载的数据写入到指定的文件中
#
# 在某些情况下用户可能会需要流式地上传和下载：
# - 用户要写入到object中的数据不能立即得到全部，而是从网络中流式获取，
#   然后再一段一段地写入到OSS中
# - 用户要写入到object的数据是经过运算得出，每次得到一部分，用户不希望
#   保留所有的数据然后一次性写入到OSS
# - 用户下载的object很大，用户不希望一次性把它们下载到内存中，而是希望
#   获取一部分就处理一部分；用户也不希望把它先下载到文件中，然后再从文
#   件中读出来处理，这样会让数据经历不必要的拷贝
#
# 当然，对于流式上传的需求，我们可以使用OSS的appendable object来满足。
# 但是即使是normal object，利用sdk的streaming功能，也可以实现流式上传
# 和下载。

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

# 例子1: 归并排序
# 有两个文件sort.1, sort.2，它们分别存了一些从小到大排列的整数，每个整
# 数1行，现在要将它们做归并排序的结果上传到OSS中，命名为sort.all

local_1, local_2 = 'sort.1', 'sort.2'
result_object = 'sort.all'

File.open(File.expand_path(local_1), 'w') do |f|
  [1001, 2005, 2007, 2011, 2013, 2015].each do |i|
    f.puts(i.to_s)
  end
end

File.open(File.expand_path(local_2), 'w') do |f|
  [2009, 2010, 2012, 2017, 2020, 9999].each do |i|
    f.puts(i.to_s)
  end
end

demo "Streaming upload" do
  bucket.put_object(result_object) do |content|
    f1 = File.open(File.expand_path(local_1))
    f2 = File.open(File.expand_path(local_2))
    v1, v2 = f1.readline, f2.readline

    until f1.eof? or f2.eof?
      if v1.to_i < v2.to_i
        content << v1
        v1 = f1.readline
      else
        content << v2
        v2 = f2.readline
      end
    end

    [v1, v2].sort.each{|i| content << i}
    content << f1.readline until f1.eof?
    content << f2.readline until f2.eof?
  end

  puts "Put object: #{result_object}"

  # 将文件下载下来查看
  bucket.get_object(result_object, :file => result_object)
  puts "Get object: #{result_object}"
  puts "Content: #{File.read(result_object)}"
end

# 例子2: 下载进度条
# 下载一个大文件（10M），在下载的过程中打印下载进度

large_file = 'large_file'

demo "Streaming download" do
  puts "Begin put object: #{large_file}"
  # 利用streaming上传
  bucket.put_object(large_file) do |stream|
    10.times { stream << "x" * (1024 * 1024) }
  end

  # 查看object大小
  object_size = bucket.get_object(large_file).size
  puts "Put object: #{large_file}, size: #{object_size}"

  # 流式下载文件，仅打印进度，不保存文件
  def to_percentile(v)
    "#{(v * 100.0).round(2)} %"
  end

  puts "Begin download: #{large_file}"
  last_got, got = 0, 0
  bucket.get_object(large_file) do |chunk|
    got += chunk.size
    # 仅在下载进度大于10%的时候打印
    if (got - last_got).to_f / object_size > 0.1
      puts "Progress: #{to_percentile(got.to_f / object_size)}"
      last_got = got
    end
  end
  puts "Get object: #{large_file}, size: #{object_size}"
end
