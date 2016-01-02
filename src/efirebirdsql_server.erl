%%% The MIT License (MIT)
%%% Copyright (c) 2016 Hajime Nakagami<nakagami@gmail.com>

-module(efirebirdsql_server).

-behavior(gen_server).

-export([start_link/0, get_parameter/2]).
-export([handle_call/3, handle_cast/2, handle_info/2]).
-export([init/1, code_change/3, terminate/2]).

-include("efirebirdsql.hrl").

-record(state, {mod,
                sock,
                db_handle,
                data = <<>>,
                parameters = [],
                types = [],
                columns = [],
                rows = [],
                results = []}).

attach_database(Sock, User, Password, Database) ->
    gen_tcp:send(Sock,
        efirebirdsql_op:op_attach(User, Password, Database)),
    case efirebirdsql_op:get_response(Sock) of
        {op_response,  R} -> R;
        _ -> {error, "Can't attach Database"}
    end.

create_database(Sock, User, Password, Database, PageSize) ->
    gen_tcp:send(Sock,
        efirebirdsql_op:op_create(User, Password, Database, PageSize)),
    case efirebirdsql_op:get_response(Sock) of
        {op_response,  R} -> R;
        _ -> {error, "Can't create database"}
    end.

%% -- client interface --
-spec start_link() -> {ok, pid()}.
start_link() ->
    gen_server:start_link(?MODULE, [], []).

get_parameter(C, Name) when is_list(Name) ->
    gen_server:call(C, {get_parameter, list_to_binary(Name)}, infinity);
get_parameter(C, Name) when is_list(Name) ->
    gen_server:call(C, {get_parameter, Name}, infinity).

%% -- gen_server implementation --

init([]) ->
    {ok, #state{}}.

handle_call({connect, Host, Username, Password, Database, Options}, _From, State) ->
    SockOptions = [{active, false}, {packet, raw}, binary],
    Port = proplists:get_value(port, Options, 3050),
    IsCreateDB = proplists:get_value(createdb, Options, false),
    PageSize = proplists:get_value(pagesize, Options, 4096),
    case gen_tcp:connect(Host, Port, SockOptions) of
        {ok, Sock} ->
            gen_tcp:send(Sock,
                efirebirdsql_op:op_connect(Host, Username, Password, Database)),
            case efirebirdsql_op:get_response(Sock) of
                {op_accept, _} ->
                    case IsCreateDB of
                        true ->
                            R = create_database(Sock, Username, Password, Database, PageSize),
                            NewState = State#state{sock = Sock},
                            {reply, R, NewState};
                        false ->
                            R = attach_database(Sock, Username, Password, Database),
                            NewState = State#state{sock = Sock},
                            {reply, R, NewState}
                    end;
                op_reject -> {reply, {error, "Connection Rejected"}, State#state{sock = Sock}}
            end;
        Error = {error, _} -> {reply, Error, State}
    end;
handle_call({close}, _From, State) ->
    %%% TODO: Do something
    {reply, ok, State};
handle_call({get_parameter, Name}, _From, State) ->
    Value1 = case lists:keysearch(Name, 1, State#state.parameters) of
        {value, {Name, Value}} -> Value;
        false                  -> undefined
    end,
    {reply, {ok, Value1}, State};
handle_call(_Msg, _From, State) ->
    {reply, {error, "Unknown command"}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({inet_reply, _, ok}, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
