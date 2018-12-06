# Wamp::Worker

[![Gem Version](https://badge.fury.io/rb/wamp-worker.svg)](https://badge.fury.io/rb/wamp_client)
[![Circle CI](https://circleci.com/gh/ericchapman/ruby_wamp_worker/tree/master.svg?&style=shield&circle-token=92813c17f9c9510c4c644e41683e7ba2572e0b2a)](https://circleci.com/gh/ericchapman/ruby_wamp_worker/tree/master)
[![Codecov](https://img.shields.io/codecov/c/github/ericchapman/ruby_wamp_worker/master.svg)](https://codecov.io/github/ericchapman/ruby_wamp_worker)

Rails worker for talking to a WAMP Router.  This is defined [here](https://tools.ietf.org/html/draft-oberstet-hybi-tavendo-wamp-02)

This is intended to replace [wamp_rails](https://github.com/ericchapman/ruby_wamp_rails).

Also see [wamp_client](https://github.com/ericchapman/ruby_wamp_client).

Wamp::Worker operates by using Redis to handle communication between your standard
Rails instances and the main Wamp::Worker "runner".

Wamp::Worker uses Wamp::Client to connect to a WAMP router.  Wamp::Client operates on top of 
EventMachine.  One nuance of EventMachine is that if an operation is blocking, it will block
handling of all incoming operations until it completes.  To remedy this, Wamp::Worker supports
integration with a Sidekiq worker in your Rails application to push the operation to a background
process.  This will allow Sidekiq to handle the operation while new requests come in.

Wamp::Worker operates using 3 different threads

 - The main thread is responsible for executing the Wamp::Client EventMachine operation which
   will establish the connection to the router.  It also listens to the 2 other threads
   looking for commands from Redis
 - The command thread listens to Redis looking for call/publish requests from the
   different Rails classes
 - The background thread listens to Redis looking for responses from handlers that were
   pushed to Sidekiq

Some notes about Wamp::Worker

 - intended to run as a Rails worker like 'Sidekiq'
 - requires a Redis connection
 - requires Sidekiq if background handlers are intended to be used
 - supports WAMP call/publish from your standard Rails classes
 - supports WAMP register/subscribe by including the "Handler" or "BackgroundHandler" modules
   to classes you create
   
## Revision History

 - v0.0.1:
   - Initial Release

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wamp-worker'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wamp-worker

## Usage

### Configuration

To configure Wamp::Worker, create a "config/initializers/wamp_worker.rb" file with the
following options

``` ruby
Wamp::Worker.configure do
  connection uri: 'ws://127.0.0.1:8080/ws', realm: 'realm1'
end
```

Note that the "connection" value is passed directly to the "Wamp::Client" module.

### Connection

### Handlers
