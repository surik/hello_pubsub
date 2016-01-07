-module(hello_pubsub).

-export([create_tables/0,

         name/0,
         router_key/0,
         validation/0,
         request/3,
         init/2,
         handle_request/4,
         handle_info/3,
         terminate/3]).

-define(HELLO_PUBSUB_TAB, hello_pubsub_tab).
-define(HELLO_PUBSUB_CLIENTS_TAB, hello_pubsub_clients_tab).

-spec create_tables() -> ok | {error, term()}.
create_tables() -> 
    Opts = [named_table, public, {read_concurrency, true}],
    case ets:new(?HELLO_PUBSUB_TAB, Opts) of
        ?HELLO_PUBSUB_TAB -> 
            case ets:new(?HELLO_PUBSUB_CLIENTS_TAB, Opts) of
                ?HELLO_PUBSUB_CLIENTS_TAB -> ok;
                Error -> Error
            end;
        Error -> Error
    end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Hello handler
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
name() -> 'hello_pubsub/pubsub'.
 
router_key() -> 'Pubsub'.
 
validation() -> ?MODULE.

request(_Module, <<"Pubsub.Subscribe">> = Method, 
        #{<<"name">> := Name, 
          <<"topic">> := Topic, 
          <<"sink">> := Sink} = Params) 
  when is_binary(Name), is_binary(Topic), is_binary(Sink) -> 
    {ok, Method, Params};

request(_Module, <<"Pubsub.Unsubscribe">> = Method, #{<<"name">> := Name} = Params)
  when is_binary(Name) ->
    {ok, Method, Params};

request(_Module, <<"Pubsub.Unsubscribe">> = Method, #{<<"topic">> := Topic} = Params)
  when is_binary(Topic) ->
    {ok, Method, Params};

request(_Module, <<"Pubsub.List">> = Method, #{<<"topic">> := Topic} = Params)
  when is_binary(Topic) ->
    {ok, Method, Params};

request(_Module, <<"Pubsub.List">> = Method,  Params) 
  when map_size(Params) == 0 ->
    {ok, Method, Params};

request(_Module, <<"Pubsub.Publish">> = Method, 
        #{<<"topic">> := Topic, <<"message">> := _} = Params)
  when is_binary(Topic) ->
    {ok, Method, Params};

request(_Module, Method, _Params) -> 
    Msg = list_to_binary(io_lib:format("bar request ~s", [Method])),
    {error, {500, Msg, undefined}}.
 
init(_Identifier, _HandlerArgs) -> 
    {ok, []}.
 
handle_request(_Context, <<"Pubsub.Subscribe">>, Args, State) ->
    {stop, normal, subscribe(Args), State};

handle_request(_Context, <<"Pubsub.Unsubscribe">>, Args, State) ->
    {stop, normal, unsubscribe(Args), State};

handle_request(_Context, <<"Pubsub.List">>, _Args, State) ->
    {stop, normal, {ok, list()}, State};

handle_request(_Context, <<"Pubsub.Publish">>, Args, State) ->
    {stop, normal, {ok, publish(Args)}, State}.
 
handle_info(_Context, _Message, State) ->
    {noreply, State}.
 
terminate(_Context, _Reason, _State) ->
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Internal functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
subscribe(#{<<"name">> := Name, <<"topic">> := Topic, <<"sink">> := Sink}) -> 
    case ets:insert_new(?HELLO_PUBSUB_TAB, {Name, parse_topic(Topic), Sink}) of
        true -> 
            if Sink /= <<"local">> -> 
                {ok, Pid} = hello_client:start(binary_to_list(Sink), [], [], []),
                ets:insert(?HELLO_PUBSUB_CLIENTS_TAB, {Sink, Pid});
            true -> skip
            end,
            {ok, ok};
        false -> {error, {404, "Already exists", []}}
    end.

unsubscribe(#{<<"name">> := Name}) -> 
    {ok, true == ets:delete(?HELLO_PUBSUB_TAB, Name) andalso ok};
unsubscribe(#{<<"topic">> := _Topic}) -> {ok, no_implemented}.

list() ->
    [#{name => Name, topic => Topic, sink => Sink} 
     || {Name, Topic, Sink} <- ets:tab2list(?HELLO_PUBSUB_TAB)].

publish(#{<<"topic">> := Topic0, <<"message">> := Message}) ->
    Topic = parse_topic(Topic0),
    Sinks = ets:foldl(fun({Name, T, Sink}, Acc) ->
                case lists:prefix(T, Topic) of 
                    true -> [{Name, Sink} | Acc];
                    false -> Acc
                end
             end, [], ?HELLO_PUBSUB_TAB),
    [begin
        Client = get_client(Sink),
        Event = {<<"Sink.Event">>, 
                 #{<<"message">> => Message, <<"id">> => Name}, 
                 [{notification, true}]},
        ok = call(Client, Event)
     end || {Name, Sink} <- Sinks].

call(local, {Method, Args, _}) ->
    Name = hello_lib:to_binary(hello_pubsub_client:name()),
    hello_service:call(Name, undefined, {Method, Args}),
    ok;
call(Client, Req) -> hello_client:call(Client, Req).
    
parse_topic(Topic) ->
    [binary_to_atom(Bin, utf8) 
     || Bin <- binary:split(Topic, <<"/">>, [global, trim]), 
        Bin /= <<"">>].

get_client(Sink) ->
    case ets:lookup(?HELLO_PUBSUB_CLIENTS_TAB, Sink) of
        [{Sink, Client}] ->
            Client;
        _ -> local
    end.
