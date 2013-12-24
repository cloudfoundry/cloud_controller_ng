require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe AppUsageEventsCleanup do
      before do
        allow(Steno).to receive(:logger).and_return(double(Steno::Logger).as_null_object)
      end

      it "can be enqueued" do
        expect(subject).to respond_to(:perform)
      end
    end
  end
end
