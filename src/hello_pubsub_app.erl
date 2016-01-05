-module(hello_pubsub_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    case application:get_env(hello_pubsub, listener_url) of
        undefined -> skip;
        {ok, Url} ->
            ok = hello_pubsub:create_tables(),
            ok = hello:bind_handler(Url, hello_pubsub, [])
    end,
    hello_pubsub_client:start(),
    hello_pubsub_sup:start_link().

stop(_State) ->
    ok.
