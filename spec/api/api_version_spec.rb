require "spec_helper"
require "digest/sha1"

describe "Stable API warning system" do
  API_FOLDER_CHECKSUM = "f4559955fba231f5f92e20dae88f370f6e91c723".freeze

  it "tells the developer if the API specs change" do
    api_folder = File.expand_path("..", __FILE__)
    files = Dir.glob("#{api_folder}/**/*").reject {|fn| File.directory?(fn) || fn == __FILE__ }.sort

    all_file_checksum = files.inject("") do |memo, f|
      memo << Digest::SHA1.file(f).hexdigest
      memo
    end

    new_checksum = Digest::SHA1.hexdigest(all_file_checksum)

    expect(new_checksum).to eql(API_FOLDER_CHECKSUM),
      "API checksum mismatch detected. Expected \n#{API_FOLDER_CHECKSUM}\n but got \n#{new_checksum}\n. You are about to make a breaking change in API. Do you really want to do it? Then update the checksum"
  end
end
