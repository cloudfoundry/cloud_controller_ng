require 'zlib'
require 'rubygems/package'

module TestCnb
  def self.create(name, file_count, file_size = 1024, &)
    File.open(name, 'wb') do |file|
      Gem::Package::TarWriter.new(file) do |tar|
        file_count.times do |i|
          tar.add_file_simple("test_#{i}", 0o644, file_size) do |f|
            f.write('A' * file_size)
          end
        end
      end
    end
  end
end
