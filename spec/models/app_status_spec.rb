require "spec_helper"

module Transferatu
  describe AppStatus do
    let(:status) { AppStatus }

    describe ".create" do
      it "raise an error because the status is a singleton" do
        expect { AppStatus.create(updated_at: Time.now, quiesced: false) }.to raise_error
      end
    end

    describe ".mark_update" do
      it "updates the updated_at time" do
        before = Time.now
        status.mark_update
        expect(status.updated_at).to be > before
      end
    end

    describe ".quiesce" do
      it "marks the system as quiesced" do
        status.quiesce
        expect(AppStatus.first.quiesced).to be true
      end
      it "updates the updated_at time" do
        before = Time.now
        status.quiesce
        expect(status.updated_at).to be > before
      end
    end

    describe ".resume" do
      it "marks the system as resumed" do
        status.resume
        expect(AppStatus.first.quiesced).to be false
      end
      it "updates the updated_at time" do
        before = Time.now
        status.resume
        expect(status.updated_at).to be > before
      end
    end

    describe ".quiesced?" do
      [true, false].each do |is_quiesced|
        it "is #{is_quiesced} when the system is #{'not ' unless is_quiesced}quiesced" do
          AppStatus.db.run "UPDATE app_status SET quiesced = #{is_quiesced}"
          expect(status.quiesced?).to be is_quiesced
        end
      end
    end

    describe "updated_at" do
      it "reflects out-of-band updates to the system" do
        before = Time.now
        AppStatus.db.run "UPDATE app_status SET updated_at = now()"
        expect(status.updated_at).to be > before        
      end
    end
  end
end
