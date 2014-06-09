require 'rspec/expectations'

RSpec::Matchers.define :be_closed do
  match do |actual|
    actual.respond_to?(:closed?) && actual.closed?
  end
end

RSpec::Matchers.define :include_element_matching do |*expected|
  match do |item|
    expected.all? do |expected_item|
      item.respond_to?(:any?) && item.any? do |elem|
        result = elem =~ expected_item
      end
    end
  end

  failure_message_for_should do |item|
    if item.respond_to?(:any?)
      "#{item} does not contain any elements matching all of: #{expected.join(', ')}"
    else
      "#{item} does not respond to :any?"
    end
  end
end
