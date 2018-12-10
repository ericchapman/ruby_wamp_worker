#!/usr/bin/env ruby

require "wamp/client"
require 'open-uri'

class Check
  attr_accessor :args, :kwargs, :details

  @@singleton = nil
  def self.shared
    @@singleton ||= self.new
  end

  def initialize
    self.clear
  end

  def clear
    self.args = nil
    self.kwargs = nil
    self.details = nil
  end

  def configure(args, kwargs, details)
    self.args = args
    self.kwargs = kwargs
    self.details = details
  end
end

def handler(args, kwargs, details)
  Check.shared.configure args, kwargs, details
end

def get_url(url, check=true)
  string = open(url).read
  if check
    result = JSON.parse(string, :symbolize_names => true)[:result]
    Check.shared.configure result[:args], result[:kwargs], {}
  end
end

def check(test, args)
  if Check.shared.args == args
    puts "#{test} PASS"
  else
    puts "#{test} FAIL, expected #{args.inspect}, got #{Check.shared.args.inspect}"
  end
end

def run_tests(tests, &complete)
  test = tests.shift
  if test
    test[0].call
    EM.add_timer(0.5) {
      check(test[1], test[2])
      run_tests(tests, &complete)
    }
  else
    complete.call
  end

end

Wamp::Client.log_level = :error

connection = Wamp::Client::Connection.new(uri: 'ws://127.0.0.1:8080/ws', realm: 'realm1')
connection.on(:join) do |session, details|

  session.subscribe "com.example.pong", method(:handler)
  session.subscribe "com.example.back.pong", method(:handler)

  tests = [
      [ -> { session.publish "com.example.ping", [1,2,3] }, "PING TEST", [1,2,3]],
      [ -> { session.publish "com.example.back.ping", [4,5,6] }, "PING BACK TEST", [4,5,6]],
      [ -> { session.call "com.example.add", [5,6] do |result, error, details|
        Check.shared.configure result[:args], result[:kwargs], details
      end }, "ADD TEST", [11]],
      [ -> { session.call "com.example.back.add", [7,8] do |result, error, details|
        Check.shared.configure result[:args], result[:kwargs], details
      end}, "ADD BACK TEST", [15]],
      [ -> { get_url "http://localhost:3000/add?a=4&b=5" }, "GET ADD TEST", [9]],
      [ -> { get_url "http://localhost:3000/ping?a=7&b=8", false }, "GET PING TEST", [7,8]],
  ]

  run_tests tests do
    connection.close
  end

end

connection.open