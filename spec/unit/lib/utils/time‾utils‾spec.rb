require 'utils/time_utils'

RSpec.describe TimeUtils do
  describe 'to_nanoseconds' do
    it 'returns an integer' do
      time = Time.now
      expect(TimeUtils.to_nanoseconds(time)).to be_a(Integer)
    end

    it 'returns nanoseconds with the appropriate precision' do
      time = Time.at(1536269249, 784009.984)
      expect(TimeUtils.to_nanoseconds(time)).to eq(1536269249784009984)
    end
  end
end
