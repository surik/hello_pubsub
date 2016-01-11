-module(hello_pubsub).

-export([subscribe/2, subscribe/3, subscribe/4,
         unsubscribe/1, 
         unsubscribe_topic/1,
         list/0, list/1,
         publish/2
        ]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-spec subscribe(binary(), function()) -> ok | {error, term()}.
subscribe(Topic, Fun) -> 
    hello_pubsub_client:subscribe(Topic, Fun).

-spec subscribe(binary(), binary(), function()) -> ok | {error, term()}.
subscribe(Topic, Name, Fun) -> 
    hello_pubsub_client:subscribe(Topic, Name, Fun).

-spec subscribe(binary(), binary(), function(), binary() | string()) -> 
    ok | {error, term()}.
subscribe(Topic, Name, Fun, Sink)  ->
    hello_pubsub_client:subscribe(Topic, Name, Fun, Sink).

-spec unsubscribe(binary()) -> ok | {error, term()}.
unsubscribe(Name) ->
    hello_pubsub_client:unsubscribe(Name).

-spec unsubscribe_topic(binary()) -> ok | {error, term()}.
unsubscribe_topic(Topic) ->
    hello_pubsub_client:unsubscribe_topic(Topic).

-spec list() -> list().
list() -> hello_pubsub_client:list().

-spec list(binary()) -> list().
list(Topic) ->
    hello_pubsub_client:list(Topic).

-spec publish(binary(), term()) -> ok.
publish(Topic, Message) ->
    hello_pubsub_client:publish(Topic, Message).
