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
         invalid_unsubscribe/1,
         concurrency_subscribe/1,
         pubsub_validation/1]).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(HELLO_PUBSUB_TEST_TAB, hello_pubsub_test_tab).

%%%===================================================================
%%% Common Test callbacks
%%%===================================================================

all() ->
    [{group, local}, 
     {group, remote},
     pubsub_validation].

groups() -> 
    [{local, [sequence], cases()},
     {remote, [sequence], cases()}].

cases() ->
    [subscribe, invalid_subscribe, 
     list, 
     publish, invalid_publish, 
     unsubscribe, invalid_unsubscribe,
     concurrency_subscribe].

init_per_suite(Config) ->
    Pid = spawn(fun EtsOwner() ->
                    receive
                        stop -> exit(normal);
                        Any -> EtsOwner()
                    end
                end),
    ?HELLO_PUBSUB_TEST_TAB = ets:new(?HELLO_PUBSUB_TEST_TAB, [named_table, public, duplicate_bag, {heir, Pid, []}]),
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
    ets:delete_all_objects(?HELLO_PUBSUB_TEST_TAB),
    ok.

%%%===================================================================
%%% Test cases
%%%===================================================================

subscribe(_Config) ->
    SubFun = fun(Topic, SubId, Msg) ->
                ets:insert(?HELLO_PUBSUB_TEST_TAB, {SubId, Msg}),
                ct:pal("~p got ~p", [SubId, Msg])
             end,
    ok = hello_pubsub_client:subscribe(<<"test">>, <<"sub_1">>, SubFun),
    ok = hello_pubsub_client:subscribe(<<"test/event2">>, <<"sub_2">>, SubFun),
    ok = hello_pubsub_client:subscribe(<<"test/event3">>, <<"sub_3">>, SubFun),
    ok.

invalid_subscribe(_Config) ->
    ?assertError(badarg, hello_pubsub_client:subscribe("test", 
                                                       fun(_, _, Msg) -> 
                                                           ct:pal("got ~p", [Msg]) 
                                                       end)),
    ?assertError(badarg, hello_pubsub_client:subscribe(<<"test">>, not_fun)),
    ?assertError(badarg, hello_pubsub_client:subscribe(<<"test">>, "sub_1",
                                                       fun(_, _, Msg) -> ct:pal("got ~p", [Msg]) end)),
    % function should be with arity 3
    ?assertError(badarg, hello_pubsub_client:subscribe(<<"test">>, <<"sub_1">>,
                                                       fun(Msg) -> ct:pal("got ~p", [Msg]) end)),
    ok.

list(_Config) ->
    3 = length(hello_pubsub_client:list()),
    ok.

publish(_Config) ->
    hello_pubsub_client:publish(<<"test/event2">>, <<"message2">>),
    hello_pubsub_client:publish(<<"test/event3">>, <<"message3">>),
    hello_pubsub_client:publish(<<"test">>, <<"message">>),
    timer:sleep(1000),
   
    3 = length(ets:lookup(?HELLO_PUBSUB_TEST_TAB, <<"sub_1">>)),
    1 = length(ets:lookup(?HELLO_PUBSUB_TEST_TAB, <<"sub_2">>)),
    1 = length(ets:lookup(?HELLO_PUBSUB_TEST_TAB, <<"sub_3">>)),
    ets:delete_all_objects(?HELLO_PUBSUB_TEST_TAB),
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

concurrency_subscribe(_Config) ->
    Count = 100,
    [begin 
         Id = <<"sub_", (integer_to_binary(N))/binary>>,
         spawn(fun() ->
             hello_pubsub_client:subscribe(<<"test">>, Id, 
                                           fun(_, _, Msg) -> 
                                                ets:insert(?HELLO_PUBSUB_TEST_TAB, {Id, Msg})
                                           end)
         end)
     end || N <- lists:seq(1, Count)],
    timer:sleep(100),

    hello_pubsub_client:publish(<<"test">>, <<"message">>),
    timer:sleep(200),

    [begin 
         Id = <<"sub_", (integer_to_binary(N))/binary>>,
         ok = hello_pubsub_client:unsubscribe(Id)
     end || N <- lists:seq(1, Count)],
    timer:sleep(100),

    0 = length(hello_pubsub_client:list()),
    Count = length(ets:tab2list(?HELLO_PUBSUB_TEST_TAB)),

    ets:delete_all_objects(?HELLO_PUBSUB_TEST_TAB),
    
    ok.

pubsub_validation(_Config) ->
    Mod = hello_pubsub,
    SubscrMsg = #{<<"name">> => <<"bin">>, <<"topic">> => <<"bin">>, <<"sink">> => <<"local">>},
    BadSubscrMsg = #{<<"name">> => "sting", <<"topic">> => "sting", <<"sink">> => "local"},
    BadSubscrMsg1 = maps:put(<<"name">>, <<"bin">>, BadSubscrMsg),
    BadSubscrMsg2 = maps:put(<<"topic">>, <<"bin">>, BadSubscrMsg1),
    BadSubscrMsg3 = maps:put(<<"topic">>, "string", SubscrMsg),
    PublishMsg = fun(Msg) -> #{<<"topic">> => <<"root">>, <<"message">> => Msg} end,

    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Subscribe">>, #{}),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Subscribe">>, #{<<"unknown_params">> => "fdf"}),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Subscribe">>, BadSubscrMsg),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Subscribe">>, BadSubscrMsg1),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Subscribe">>, BadSubscrMsg2),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Subscribe">>, BadSubscrMsg3),
    {ok, <<"Pubsub.Subscribe">>, _} = hello_pubsub:request(Mod, <<"Pubsub.Subscribe">>, SubscrMsg),

    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Unsubscribe">>, #{}),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Unsubscribe">>, #{<<"unknown_params">> => "fdf"}),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Unsubscribe">>, #{<<"name">> => "string"}),
    {ok, <<"Pubsub.Unsubscribe">>, _} = hello_pubsub:request(Mod, <<"Pubsub.Unsubscribe">>, 
                                                             #{<<"name">> => <<"bin">>}),

    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.List">>, #{<<"topic">> => "topic"}),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.List">>, #{<<"unknown_params">> => "fdf"}),
    {ok, <<"Pubsub.List">>, _} = hello_pubsub:request(Mod, <<"Pubsub.List">>, #{}),
    {ok, <<"Pubsub.List">>, _} = hello_pubsub:request(Mod, <<"Pubsub.List">>, #{<<"topic">> => <<"topic">>}),

    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Publish">>, #{}),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Publish">>, #{<<"topic">> => "list"}),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Publish">>, #{<<"topic">> => <<"bin">>}),
    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.Publish">>, #{<<"unknown_params">> => "fdf"}),
    {ok, <<"Pubsub.Publish">>, _} = hello_pubsub:request(Mod, <<"Pubsub.Publish">>, PublishMsg(<<"message">>)),
    {ok, <<"Pubsub.Publish">>, _} = hello_pubsub:request(Mod, <<"Pubsub.Publish">>, 
                                                         PublishMsg(#{<<"payload">> => <<"message">>})),

    {error, _} = hello_pubsub:request(Mod, <<"Pubsub.UndefMethod">>, #{}),
    ok.
