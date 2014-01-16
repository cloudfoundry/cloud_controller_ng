require "spec_helper"
require "digest/sha1"

describe "Stable API warning system", api_version_check: true do
  API_FOLDER_CHECKSUM = "515f998afc25c9a2ef1e1b1fb7e8b977e7336545".freeze

  it "tells the developer if the API specs change" do
    api_folder = File.expand_path("..", __FILE__)
    files = Dir.glob("#{api_folder}/**/*").reject {|fn| File.directory?(fn) || fn == __FILE__ }.sort

    all_file_checksum = files.inject("") do |memo, f|
      memo << Digest::SHA1.file(f).hexdigest
      memo
    end

    new_checksum = Digest::SHA1.hexdigest(all_file_checksum)

    expect(new_checksum).to eql(API_FOLDER_CHECKSUM),
      <<-END
API checksum mismatch detected. Expected:
  #{API_FOLDER_CHECKSUM}
but got:
  #{new_checksum}
You are about to make a breaking change in API. Do you really want to do it? Then update the checksum & CC version.
END
  end
end
