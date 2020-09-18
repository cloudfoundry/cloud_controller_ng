require 'lightweight_spec_helper'
require 'cloud_controller/yaml_config'

module VCAP::CloudController
  RSpec.describe YAMLConfig do
    describe '.from_file' do
      let!(:tmpyml) do
        Tempfile.open('') do |tmpfile|
          tmpfile.write(file_contents)
          tmpfile
        end
      end

      context 'when the YAML does not contain any non-whitelisted objects' do
        let(:file_contents) { 'hello: yaml' }

        it 'uses YAML.safe_load to parse the contents of the file' do
          expect(YAML).to receive(:safe_load).and_wrap_original do |safe_load, f|
            expect(f.path).to eq(tmpyml.path)
            safe_load.call(f, [Symbol])
          end

          expect(YAMLConfig.safe_load_file(tmpyml.path)).to eq({ 'hello' => 'yaml' })
        end
      end

      context 'when the YAML contains non-whitelisted objects' do
        let(:file_contents) { "--- !ruby/hash:Dog\nhello: yaml" }

        before do
          stub_const 'Dog', Class.new(Hash)
        end

        it 'raises an error' do
          expect {
            YAMLConfig.safe_load_file(tmpyml.path)
          }.to raise_error(Psych::DisallowedClass, 'Tried to load unspecified class: Dog')
        end
      end
    end
  end
end
