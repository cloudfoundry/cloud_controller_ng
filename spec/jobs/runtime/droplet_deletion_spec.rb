require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe DropletDeletion do
      let(:old_droplet_key) { "abcdefh" }
      let(:new_droplet_key) { "zyxwvy" }
      subject(:job) { DropletDeletion.new(new_droplet_key, old_droplet_key) }

      describe "#perform" do
        let!(:droplet_blobstore) {
          CloudController::DependencyLocator.instance.droplet_blobstore
        }

        before do
          CloudController::DependencyLocator.instance.stub(:droplet_blobstore).
            and_return(droplet_blobstore)
        end

        it "should delete the droplet" do
          expect(droplet_blobstore).to receive(:delete).with(new_droplet_key).ordered
          expect(droplet_blobstore).to receive(:delete).with(old_droplet_key).ordered
          job.perform
        end

        context "with only one droplet associated with the app" do
          # working around a problem with local blob stores where the old format
          # key is also the parent directory, and trying to delete it when there are
          # multiple versions of the app results in an "is a directory" error
          it "it hides EISDIR if raised by the blob store on deleting the old format of the droplet key" do
            droplet_blobstore.stub(:delete).with(new_droplet_key)
            droplet_blobstore.stub(:delete).with(old_droplet_key).and_raise Errno::EISDIR
            expect { job.perform }.to_not raise_error
          end

          it "it doesn't hide EISDIR if raised for the new droplet key format" do
            droplet_blobstore.stub(:delete).with(new_droplet_key).and_raise Errno::EISDIR
            expect { job.perform }.to raise_error
          end

          it "it doesn't hide error other than EISDIR" do
            expect(droplet_blobstore).to receive(:delete).with(new_droplet_key).ordered
            expect(droplet_blobstore).to receive(:delete).with(old_droplet_key).ordered.and_raise Errno::EINVAL
            expect { job.perform }.to raise_error(Errno::EINVAL)
          end
        end
      end

      it "knows its job name" do
        expect(job.job_name_in_configuration).to equal(:droplet_deletion)
      end

      describe "#max_attempts" do
        it "should return the configured max attempts (or expected)" do
          expect(job.max_attempts).to eq(3)
        end
      end
    end
  end
end
