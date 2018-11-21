require "spec_helper"

describe Wamp::Worker do
  it "has a version number" do
    expect(Wamp::Worker::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
