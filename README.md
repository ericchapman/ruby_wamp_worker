# Wamp::Worker

[![Gem Version](https://badge.fury.io/rb/wamp-worker.svg)](https://badge.fury.io/rb/wamp-worker)
[![CI Status](https://travis-ci.org/ericchapman/ruby_wamp_worker.svg?branch=master)](https://travis-ci.org/ericchapman/ruby_wamp_worker)
[![Codecov](https://img.shields.io/codecov/c/github/ericchapman/ruby_wamp_worker/master.svg)](https://codecov.io/github/ericchapman/ruby_wamp_worker)

Rails worker for talking to a WAMP Router which is described [here](https://tools.ietf.org/html/draft-oberstet-hybi-tavendo-wamp-02)

This GEM is intended to replace [wamp_rails](https://github.com/ericchapman/ruby_wamp_rails).
 
This GEM is written using [wamp_client](https://github.com/ericchapman/ruby_wamp_client) to connect
to a WAMP router.

This GEM operates by using Redis to handle communication between your standard
Rails instances and the main Wamp::Worker "runner".

This GEM uses [Wamp::Client](https://github.com/ericchapman/ruby_wamp_client) to connect 
to a WAMP router.  Wamp::Client operates on top of EventMachine.  One nuance of EventMachine 
is that if an operation is blocking, it will block handling of all incoming operations until 
it completes.  To remedy this, Wamp::Worker supports integration with a Sidekiq worker in your 
Rails application to push the operation to a background process.  This will allow Sidekiq to 
handle the operation while new requests come in.

This GEM operates using 2 different threads

 - The main thread is responsible for executing the Wamp::Client EventMachine operation which
   will establish the connection to the router.  It also listens to the 2 other threads
   looking for commands from Redis
 - The other thread connects to Redis waiting for jobs to be pushed from either a Rails source
   or jobs that were pushed to a background worker.  As it receives responses, it will pass
   them to the main thread for processing.

Some notes about Wamp::Worker

 - intended to run as a Rails worker like 'Sidekiq'
 - requires a Redis connection
 - requires Sidekiq if background handlers are intended to be used
 - supports WAMP call/publish from your standard Rails classes
 - supports WAMP register/subscribe by including the "Handler" or "BackgroundHandler" modules
   to classes you create
   - BackgroundHandler requires Sidekiq
   
## Revision History

 - v0.0.2:
   - Updated to use Wamp::Client logger
   - Other minor cleanup
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

To configure Wamp::Worker, create a initializer file with the following options

**config/initializers/wamp-worker.rb**

``` ruby
Wamp::Worker.configure do
  timeout 30
  redis Redis.new
  connection uri: 'ws://127.0.0.1:8080/ws', realm: 'realm1'
end
```

The attributes are defined as follows

 - timeout - (default: 60) number of seconds a "call" will wait before timing out
 - redis - (default: Redis.new) either a Redis object or parameters to pass to 
   creating a Redis object
 - connection - options to pass to the "Wamp::Client::Connection".  See 
   [wamp_client](https://github.com/ericchapman/ruby_wamp_client) for more details

You can also "subscribe" and "register" in the configuration object.  That will be 
described later.

**Note that you MUST make sure "config.eager_load = true" is set in the environment files
located in "config/environments/\*.rb"**

### Multiple Workers

Wamp::Worker supports creating multiple workers with different options.  To do this,
pass a "name" to the "configure" method like below

``` ruby
Wamp::Worker.configure do
  connection uri: 'ws://127.0.0.1:8080/ws', realm: 'realm1'
end

Wamp::Worker.configure :other do
  connection uri: 'ws://127.0.0.1:8080/ws', realm: 'realm2'
end
```

When the name is omitted, it will use the name ":default".

### Handlers

Handlers are controllers used to implement "subscribe" and "register" callbacks. An 
example of one is shown below

**app/handlers/my_handler.rb**

``` ruby
class MyHandler
  include Wamp::Worker::Handler

  register "com.example.add", :add, { invoke: "roundrobin" }
  register "com.example.subtract", :subtract, { invoke: "roundrobin" }
  subscribe "com.example.listener", :listener

  def add
    args[0] + args[1]
  end
  
  def subtract
    args[0] - args[1]
  end
  
  def listener
    # Do something
  end

end
```

You can also "register" and "subscribe" in the configure block

``` ruby
Wamp::Worker.configure do
  connection uri: 'ws://127.0.0.1:8080/ws', realm: 'realm1'
  
  register "com.example.add", MyHandler, :add, { invoke: "roundrobin" }
  register "com.example.subtract", MyHandler, :subtract, { invoke: "roundrobin" }
  subscribe "com.example.listener", MyHandler, :listener
end
```

#### Background Handlers

For Rails applications that have Sidekiq, you can push the processing of the handler
to the background by including "Wamp::Worker::BackgroundHandler" instead of
"Wamp::Worker::Handler".

### Call/Publish Methods

The library also supports "call" and "publish" methods from objects outside of the
worker.  This is done by including "Wamp::Worker::Session" in your class.  For example

**app/controllers/add_controller.rb**

``` ruby
class AddController < ApplicationController
  include Wamp::Worker::Session.new
  
  def index
    response = nil

    self.wamp_session.call "com.example.back.add", [params[:a].to_i, params[:b].to_i] do |result, error, details|
      response = result
    end

    render json: { result: response }
  end
end
```

Note that the name defaults to ":default" and the method "wamp_session".  These
can be overridden by adding the following attributes to the "include"

**app/controllers/add_controller.rb**

``` ruby
class AddController < ApplicationController
  include Wamp::Worker::Session.new, :other, :different_session
  
  def index
    response = nil

    self.different_session.call "com.example.back.add", [params[:a].to_i, params[:b].to_i] do |result, error, details|
      response = result
    end

    render json: { result: response }
  end
end
```

This will talk to the ":other" worker and expose it using "different_session"
rather than "wamp_session"

### Starting the Worker

There are 2 different ways you can start a worker

#### Rails/Heroku worker

To start the worker, use the "wamp-worker" executable

    $ bundle exec wamp-worker
    
This executable supports the following options

 - "-l" (default: "info"): logging level (debug, info, warn, error)
 - "-n" (default: "default"): name of the worker
 - "-e" (default: "development"): application environment to load

or in your Procfile for Heroku

**Procfile**

```
web: bundle exec puma -C config/puma.rb
worker: bundle exec wamp-worker -e production
```

#### Thread

You can also spawn a thread inside if your application.  One way to do this
is as follows

**config/initializers/wamp-worker.rb**

``` ruby
require "thread"

Thread.new do
  Wamp::Worker.run uri: 'ws://127.0.0.1:8080/ws', realm: 'realm1'
end
```

Note that this method is not recommended for scalable designs because it will
create a new instance of the worker every time you scale the web instance.
Only do this if you really know what you are doing.

Also, when calling "register", you must include the "invoke" option.  See WAMP
documentation for more details.
