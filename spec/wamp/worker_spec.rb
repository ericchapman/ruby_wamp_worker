require "spec_helper"

describe Wamp::Worker do
  it "has a version number" do
    expect(Wamp::Worker::VERSION).not_to be nil
  end

end
