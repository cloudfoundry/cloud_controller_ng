require 'zip'

module TestZip
  def self.create(zip_name, file_count, file_size=1024, &blk)
    Zip::File.open(zip_name, Zip::File::CREATE) do |zipfile|
      file_count.times do |i|
        zipfile.get_output_stream("ziptest_#{i}") do |f|
          f.write('A' * file_size)
        end
      end

      blk.call(zipfile) if blk
    end
  end
end
