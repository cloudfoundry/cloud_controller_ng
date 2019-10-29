require 'spec_helper'
require 'utils/yaml_utils'

RSpec.describe YamlUtils, :focus do
  describe 'truncate' do
    it 'truncates non-yaml strings' do
      s1 = '{234567890'
      new_s1 = YamlUtils.truncate(s1, 9)
      expect(new_s1).to eq(s1[0..8])
    end

    it 'truncates strings' do
      s1 = 's123456789'
      new_s1 = YAML.safe_load(YamlUtils.truncate(s1, 9))
      expect(YAML.safe_load(new_s1)).to eq(s1[0..8])
    end

    it 'truncates long arrays from last backwards' do
      input = %w/a234567890 b234567890 c234567890 d234567890/
      # 30 because yaml adds a lot of crap
      result = YamlUtils.truncate(YAML.dump(input), 30)
      expect(YAML.safe_load(result)).to match_array(input[0...2])
    end

    it 'truncates long arrays in hashes' do
      input = {
        'a1' => %w/a234567890 1234567890 2234567890/,
        'b1' => %w/b234567890 1234567890 2234567890 3234567890/,
        'c1' => %w/c234567890/,
        'd1' => %w/d234567890 1234567890/,
        'e1' => %w/e234567890/,
      }
      # The max-size allows for the extra punctuation yaml-encoding adds
      result = YAML.safe_load(YamlUtils.truncate(YAML.dump(input), 40))
      expect(result.keys.size).to eq(3)
      expect(result).to match(
        {
          'c1' => %w/c234567890/,
          'd1' => [],
          'e1' => %w/e234567890/,
        }
      )
      result = YAML.safe_load(YamlUtils.truncate(YAML.dump(input), 72))
      expect(result.keys.size).to eq(4)
      expect(result).to match(
        {
          'a1' => [],
          'c1' => %w/c234567890/,
          'd1' => %w/d234567890 1234567890/,
          'e1' => %w/e234567890/,
        }
      )
      result = YAML.safe_load(YamlUtils.truncate(YAML.dump(input), 84))
      expect(result.keys.size).to eq(4)
      expect(result).to match(
        {
          'a1' => %w/a234567890/,
          'c1' => %w/c234567890/,
          'd1' => %w/d234567890 1234567890/,
          'e1' => %w/e234567890/,
        }
      )
    end

    it 'burrows through nested objects to find the longest items' do
      input = {
        'a1' => {
          'a11' => 'scalar',
          'a12' => 3,
          'a13' => %w/a234567890 1234567890 2234567890/,
        },
        'b1' => [
          %w/b234567890 1234567890 2234567890 3234567890/,
          3,
          'b1-scalar'
        ],
      }
      result = YAML.safe_load(YamlUtils.truncate(YAML.dump(input), 35))
      expect(result.keys.size).to eq(1)
      expect(result).to match(
        {
          'a1' => {
            'a11' => 'scalar',
            'a12' => 3,
            'a13' => %w/a234567890/,
          },
        }
      )
    end
  end
end
