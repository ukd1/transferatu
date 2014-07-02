require "spec_helper"

module Transferatu
  describe User do
    let(:password)     { "hunter2" }
    let(:bad_password) { "passw0rd" }
    let(:user)         { create(:user, password: password) }

    it "should recognize the right password" do
      expect(user.password == password).to be true
    end

    it "should not recognize an incorrect password" do
      expect(user.password == bad_password).to be false
    end
    
    it "should not store the password in the database" do
      user.reload
      expect(user.values.find { |k,v| v == password }).to be_nil
    end
  end
end
