require "wamp/worker"

Wamp::Worker.log_level = :debug

Wamp::Worker.configure do
  connection uri: 'ws://127.0.0.1:8080/ws', realm: 'realm1', verbose: true
end

