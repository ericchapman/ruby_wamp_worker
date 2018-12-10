class ApplicationController < ActionController::Base
  include Wamp::Worker::Session.new
end
