require "spec_helper"
require "digest/sha1"

describe "Stable API warning system", api_version_check: true do
  API_FOLDER_CHECKSUM = "8327cd645120d79e24bc197f687807c93a42f370".freeze

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
