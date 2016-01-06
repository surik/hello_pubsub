# Hello PubSub [![Build Status](https://travis-ci.org/surik/hello_pubsub.svg)](https://travis-ci.org/surik/hello_pubsub)

Publisher-Subscriber implementation over [hello](https://github.com/travelping/hello) framework.

# Building and installing

Use [rebar](https://github.com/rebar/rebar) for building:
    
    rebar get-deps compile

You can use `hello_pubsub` in your own project:

    {deps, [
        {hello_pubsub, ".*", {git, "https://github.com/surik/hello_pubsub.git", "master"}}
    ]}.

and ensure `hello_pubsub` is starder before your application:

    {applications, [hello_pubsub]}.

# Using
    
`hello_pubsub` has the following environment options:

* __listener_url__ - URL for binding pubsub API. When `hello_pubsub` is started `hello_pubsub` handler will be binded to this listener. This makes pubsub API available on `<listener_url>/pubsub`. `http://127.0.0.1:8081` by default.

* __connect_to__ - URL for client connect. `local` means all pubsub APIs will be evaluated on local node. `local` by default.

* __sink__ - default URL for sending events. `local` means you will be getting notification on local node. `local` by default.


Example:

```erlang
{ok, _} = application:ensure_all_started(hello_pubsub),
hello_pubsub_client:subscribe(<<"/root">>, <<"sub_1">>, 
                              fun(Msg) -> io:format("got ~p", [Msg]) end),

% prints "got <<"message">>" 
hello_pubsub_client:publish(<<"/root/event1">>, <<"message">>),

% prints "got <<"message1">>"
hello_pubsub_client:publish(<<"/root>>, <<"message1">>),

% prints nothing because here isn't subscription for 'another_root'
hello_pubsub_client:publish(<<"/another_root>>, <<"message">>),

hello_pubsub_client:unsubscribe(<<"sub_1">>).

% prints nothing because subscription no mote available
hello_pubsub_client:publish(<<"/root/event1">>, <<"message">>).
```

Topics are trees. You can subscribe to `/root/` and receive events from all nested `/root/...` topics.
