require "spec_helper"
require "cloud_controller/clock"

module VCAP::CloudController
  describe Clock do
    describe "#start" do
      let(:logger) do
        double(Steno::Logger)
      end

      before do
        Steno.stub(logger: logger)

        allow(logger).to receive(:info)
        allow(Clockwork).to receive(:every).and_yield("dummy.scheduled.job")
        allow(Clockwork).to receive(:run)

        Clock.start
      end

      it "schedules a dummy job to run every 10 minutes" do
        expect(Clockwork).to have_received(:every).with(10.minutes, "dummy.scheduled.job")
      end

      it "logs a message every time the job runs" do
        expect(Steno).to have_received(:logger).with("cc.clock")
        expect(logger).to have_received(:info).with("Would have run dummy.scheduled.job")
      end

      it "runs Clockwork" do
        expect(Clockwork).to have_received(:run)
      end
    end
  end
end
