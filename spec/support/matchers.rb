require 'rspec/expectations'

RSpec::Matchers.define :be_closed do
  match do |actual|
    actual.respond_to?(:closed?) && actual.closed?
  end
end
