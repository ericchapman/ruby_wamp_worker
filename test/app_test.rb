#!/usr/bin/env ruby

require "wamp/client"
require 'open-uri'

class Check
  attr_accessor :args, :kwargs, :details, :progress

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
    self.progress = 0
  end

  def configure(args, kwargs, details)
    self.args = args
    self.kwargs = kwargs
    self.details = details || {}

    if self.details[:progress]
      puts "PROGRESS: #{args.inspect}"
      self.progress += 1
    end
  end
end

def handler(args, kwargs, details)
  Check.shared.configure args, kwargs, details
end

def callback(result, error, details)
  if error
    puts "ERROR"
    puts error.inspect
  else
    Check.shared.configure result[:args], result[:kwargs], details
  end
end

def get_url(url, check=true)
  string = open(url).read
  if check
    result = JSON.parse(string, :symbolize_names => true)[:result]
    Check.shared.configure result[:args], result[:kwargs], {}
  end
end

def check(test, args, progress=nil)
  progress ||= 0
  error = false

  if Check.shared.args != args
    puts "#{test} ARGS FAIL, expected #{args.inspect}, got #{Check.shared.args.inspect}"
    error = true
  end

  if Check.shared.progress != progress
    puts "#{test} PROGRESS FAIL, expected #{progress}, got #{Check.shared.progress}"
    error = true
  end

  puts "#{test} PASS" unless error

  Check.shared.clear
end

def run_tests(tests, &complete)
  test = tests.shift
  if test
    test[0].call
    EM.add_timer(0.5) {
      check(test[1], test[2], test[3])
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
        callback result, error, details
      end }, "ADD TEST", [11]],
      [ -> { session.call "com.example.back.add", [7,8] do |result, error, details|
        callback result, error, details
      end}, "ADD BACK TEST", [15]],
      [ -> { session.call "com.example.back.add.delay", [11,2], {}, { receive_progress: false } do |result, error, details|
        callback result, error, details
      end}, "NO PROGRESS DELAY ADD BACK TEST", [13], 0],
      [ -> { session.call "com.example.back.add.delay", [3,2], {}, { receive_progress: true } do |result, error, details|
        callback result, error, details
      end}, "PROGRESS DELAY ADD BACK TEST", [5], 4],
      [ -> { get_url "http://localhost:3000/add?a=4&b=5" }, "GET ADD TEST", [9]],
      [ -> { get_url "http://localhost:3000/ping?a=7&b=8", false }, "GET PING TEST", [7,8]],
  ]

  run_tests tests do
    connection.close
  end

end

connection.open