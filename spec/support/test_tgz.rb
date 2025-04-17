require 'zlib'
require 'rubygems/package'

module TestTgz
  def self.create(tgz_name, file_count, file_size=1024, &)
    File.open(tgz_name, 'wb') do |file|
      Zlib::GzipWriter.wrap(file) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |tar|
          file_count.times do |i|
            tar.add_file_simple("ziptest_#{i}", 0o644, file_size) do |f|
              f.write('A' * file_size)
            end
          end
        end
      end
    end
  end
end
