% @private
-module(hello_pubsub_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    case application:get_env(hello_pubsub, pubsub_listener_url) of
        undefined -> skip;
        {ok, Url} ->
            ok = hello_pubsub_handler:create_tables(),
            ok = hello:bind(Url, hello_pubsub_handler, [])
    end,
    hello_pubsub_client:start(),
    hello_pubsub_sup:start_link().

stop(_State) ->
    ok.
