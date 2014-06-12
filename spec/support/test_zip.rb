module TestZip
  def self.create(zip_name, file_count, file_size=1024)
    files = []
    file_count.times do |i|
      tf = Tempfile.new("ziptest_#{i}")
      files << tf
      tf.write("A" * file_size)
      tf.close
    end

    child = POSIX::Spawn::Child.new("zip", zip_name, *files.map(&:path))
    child.status.exitstatus == 0 or raise "Failed zipping:\n#{child.err}\n#{child.out}"
  end
end
