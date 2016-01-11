% @private
-module(hello_pubsub_client).

-export([start/0,
         create_tables/0,

         name/0,
         router_key/0,
         validation/0,
         request/3,
         init/2,
         handle_request/4,
         handle_info/3,
         terminate/3,

         subscribe/2, subscribe/3, subscribe/4,
         unsubscribe/1, 
         unsubscribe_topic/1,
         list/0, list/1,
         publish/2
        ]).

-define(HELLO_CLIENT_PUBSUB_TAB, hello_client_pubsub_tab).


-spec start() -> {ok, pid()}.
start() ->
    ok = create_tables(),
    case application:get_env(hello_pubsub, connect_to, local) of
        local -> hello_service:register_link(?MODULE, []);
        Url ->
            ok = hello:bind(Url, ?MODULE, []),
            hello_client:start_supervised(?MODULE, Url ++ "/pubsub", [], [], [])
    end.

-spec create_tables() -> ok | {error, term()}.
create_tables() -> 
    Opts = [named_table, public, {read_concurrency, true}],
    case ets:new(?HELLO_CLIENT_PUBSUB_TAB, Opts) of
        ?HELLO_CLIENT_PUBSUB_TAB -> ok;
        Error -> Error
    end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Hello handler
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
name() -> 'hello_pubsub/sink'.
 
router_key() -> 'Sink'.

validation() -> ?MODULE.

request(_Module, Method, Params) -> 
    {ok, Method, Params}.
 
init(_Identifier, _HandlerArgs) -> 
    {ok, []}.
 
handle_request(_Context, <<"Sink.Event">>, 
               #{<<"topic">> := Topic, 
                 <<"id">> := Id, 
                 <<"message">> := Msg}, State) ->
    case ets:lookup(?HELLO_CLIENT_PUBSUB_TAB, Id) of
        [{Id, _, Fun}] -> Fun(Topic, Id, Msg);
        _ -> skip
    end,
    {stop, normal, {ok, ok}, State}.
 
handle_info(_Context, _Message, State) ->
    {noreply, State}.
 
terminate(_Context, _Reason, _State) ->
    ok.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-spec subscribe(binary(), function()) -> ok | {error, term()}.
subscribe(Topic, Fun) -> 
    subscribe(Topic, generate_name(), Fun).

-spec subscribe(binary(), binary(), function()) -> ok | {error, term()}.
subscribe(Topic, Name, Fun) -> 
    DefaultSink = application:get_env(hello_pubsub, sink, "local"),
    subscribe(Topic, Name, Fun, hello_lib:to_binary(DefaultSink)).

-spec subscribe(binary(), binary(), function(), binary() | string()) -> 
    ok | {error, term()}.
subscribe(Topic, Name, Fun, Sink0) 
  when is_binary(Topic), is_binary(Name), is_function(Fun) ->
    {arity, Arity} = erlang:fun_info(Fun, arity),
    if Arity =:= 3 ->
        Sink = hello_lib:to_binary(Sink0),
        case call(<<"Pubsub.Subscribe">>, #{topic => Topic, name => Name, sink => Sink}) of
            ok -> 
                true = ets:insert_new(?HELLO_CLIENT_PUBSUB_TAB, {Name, Topic, Fun}),
                ok;
            Error -> Error
        end;
    true -> error(badarg)
    end;
subscribe(_, _, _, _) -> error(badarg).

-spec unsubscribe(binary()) -> ok | {error, term()}.
unsubscribe(Name) when is_binary(Name) ->
    case call(<<"Pubsub.Unsubscribe">>, #{name => Name}) of
        ok -> 
            true = ets:delete(?HELLO_CLIENT_PUBSUB_TAB, Name),
            ok;
        Error -> Error
    end;
unsubscribe(_) -> error(badarg).

-spec unsubscribe_topic(binary()) -> ok | {error, term()}.
unsubscribe_topic(Topic) when is_binary(Topic) -> 
    call(<<"Pubsub.Unsubscribe">>, #{topic => Topic});
unsubscribe_topic(_) -> error(badarg).

-spec list() -> list().
list() -> call(<<"Pubsub.List">>, #{}).

-spec list(binary()) -> list().
list(Topic) when is_binary(Topic) -> 
    call(<<"Pubsub.List">>, #{topic => Topic});
list(_) -> error(badarg).

-spec publish(binary(), term()) -> ok.
publish(Topic, Message) when is_binary(Topic) ->
    call(<<"Pubsub.Publish">>, #{topic => Topic, 
                                 message => Message});
publish(_, _) -> error(badarg).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Internal functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
call(Method, Args) ->
    case call({Method, Args, []}) of
        {ok, <<"ok">>} -> ok;
        {ok, R} when is_map(R) -> maps:to_list(R);
        {ok, R} -> R;
        R -> R
    end.

call({Method, Args, _} = Req) ->
    case application:get_env(hello_pubsub, connect_to, local) of
        local -> 
            Name = hello_lib:to_binary(hello_pubsub_handler:name()),
            hello_service:call(Name, undefined, {Method, hello_json:decode(hello_json:encode(Args))});
        _ -> hello_client:call(?MODULE, Req)
    end.


%%% XXX: use better uuid generator
generate_name() -> 
    Num = erlang:phash2({node(), make_ref()}),
    <<"sub_", (integer_to_binary(Num))/binary>>.
