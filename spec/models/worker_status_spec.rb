require "spec_helper"

describe Transferatu::WorkerStatus do
  describe "#dyno_name" do
    it "is not overridden if set" do
      name = 'elvis'
      s = create(:worker_status, dyno_name: name)
      expect(s.dyno_name).to eq name
    end

    it "is picked up from the environment if nil" do
      name = 'dianne...-o'
      ENV['DYNO'] = name
      s = create(:worker_status, dyno_name: nil)
      expect(s.dyno_name).to eq name
    end
  end

  describe "#uuid" do
    it "is not overriden if set" do
      some_uuid = '1da03a5e-4ecb-4e27-9fbe-f4e131216151'
      s = create(:worker_status, uuid: some_uuid)
      expect(s.uuid).to eq some_uuid
    end

    it "is picked up from the hostname if nil" do
      some_uuid = 'd103a5ea-4ceb-742e-fb9e-fe4312111156'
      expect(Socket).to receive(:gethostname).and_return(some_uuid)
      s = create(:worker_status, uuid: nil)
      expect(s.uuid).to eq some_uuid
    end
  end

  describe "#host" do
    it "is not overriden if set" do
      some_external_ip = '172.17.120.122'
      s = create(:worker_status, host: some_external_ip)
      expect(s.host).to eq some_external_ip
    end

    it "is pulled from /etc/hosts" do
      some_external_ip = '172.17.120.122'
      some_internal_ip = '10.8.162.146'
      some_uuid = '1da03a5e-4ecb-4e27-9fbe-f4e131216151'
      expect(File).to receive(:readlines).with('/etc/hosts')
        .and_return(<<-EOF.split("\n"))
127.0.0.1 localhost localhost.localdomain
#{some_external_ip} #{some_uuid}.prvt.dyno.rt.heroku.com
#{some_external_ip} #{some_uuid}
#{some_internal_ip} #{some_uuid}.int.dyno.rt.heroku.com
EOF

      # N.B.: the above is what /etc/hosts more or less looks like
      # on Heroku today; this may need to adapt as that changes;
      # we can't rely on a stable contract here. If you know of a
      # simpler, safer way to do this, I'm all ears.
      s = create(:worker_status, uuid: some_uuid, host: nil)
      expect(s.host).to eq some_external_ip
    end
  end
end
