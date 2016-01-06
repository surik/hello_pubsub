-module(hello_pubsub_SUITE).

%% Common Test callbacks
-export([all/0,
         groups/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_group/2,
         end_per_group/2]).

%% Test cases
-export([subscribe/1,
         invalid_subscribe/1,
         list/1,
         invalid_publish/1,
         publish/1,
         unsubscribe/1,
         invalid_unsubscribe/1]).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

%%%===================================================================
%%% Common Test callbacks
%%%===================================================================

all() ->
    [{group, local}, 
     {group, remote}].

groups() -> 
    [{local, [sequence], cases()},
     {remote, [sequence], cases()}].

cases() ->
    [subscribe, invalid_subscribe, 
     list, 
     publish, invalid_publish, 
     unsubscribe, invalid_unsubscribe].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

init_per_group(Group, Config) ->
    case Group of
        local -> ok;
        remote -> 
            application:set_env(hello_pubsub, connect_to, "http://127.0.0.1:8081"),
            application:set_env(hello_pubsub, sink, "http://127.0.0.1:8081/sink")
    end,
    {ok, _} = application:ensure_all_started(hello),
    {ok, _} = application:ensure_all_started(hello_pubsub),
    Config.

end_per_group(Group, _Config) ->
    ok = application:stop(hello_pubsub),
    ok = application:stop(hello),
    ok.

%%%===================================================================
%%% Test cases
%%%===================================================================

subscribe(_Config) ->
    ok, hello_pubsub_client:subscribe(<<"test">>, <<"sub_1">>, 
                                      fun(Msg) -> ct:pal("got ~p", [Msg]) end),
    ok, hello_pubsub_client:subscribe(<<"test/event2">>, <<"sub_2">>, 
                                      fun(Msg) -> ct:pal("2 got ~p", [Msg]) end),
    ok, hello_pubsub_client:subscribe(<<"test/event3">>, <<"sub_3">>, 
                                      fun(Msg) -> ct:pal("3 got ~p", [Msg]) end),
    ok.

invalid_subscribe(_Config) ->
    ?assertError(badarg, hello_pubsub_client:subscribe("test", fun(Msg) -> ct:pal("got ~p", [Msg]) end)),
    ?assertError(badarg, hello_pubsub_client:subscribe(<<"test">>, not_fun)),
    ?assertError(badarg, hello_pubsub_client:subscribe(<<"test">>, "sub_1",
                                                       fun(Msg) -> ct:pal("got ~p", [Msg]) end)),
    ok.

list(_Config) ->
    3 = length(hello_pubsub_client:list()),
    ok.

publish(_Config) ->
    hello_pubsub_client:publish(<<"test/event2">>, <<"message2">>),
    hello_pubsub_client:publish(<<"test/event3">>, <<"message3">>),
    hello_pubsub_client:publish(<<"test">>, <<"message">>),
    timer:sleep(500),
    ok.

invalid_publish(_Config) ->
    ?assertError(badarg, hello_pubsub_client:publish("test/event2", <<"message2">>)),
    ok.

unsubscribe(_Config) ->
    ok = hello_pubsub_client:unsubscribe(<<"sub_1">>),
    ok = hello_pubsub_client:unsubscribe(<<"sub_2">>),
    1 = length(hello_pubsub_client:list()),
    ok = hello_pubsub_client:unsubscribe(<<"sub_3">>),
    0 = length(hello_pubsub_client:list()),
    ok.

invalid_unsubscribe(_Config) ->
    ?assertError(badarg, hello_pubsub_client:unsubscribe("test/event2")),
    ok.
