-module(erchat_handler).

-export([init/4]).
-export([stream/3]).
-export([info/3]).
-export([terminate/2]).


init(_Transport, Req, _Opts, _Active) ->
  {BitUUID, Req2} = cowboy_req:binding(uuid, Req),
  UUID = erlang:binary_to_list(BitUUID),
  case rooms_server:get_room_pid(UUID) of
    undefined ->
      erlang:display(undefined),
      {shutdown, Req2, []};
    Pid ->
      gproc:reg({p, l, UUID}),
      {ok, Req2, {Pid, empty}}
      %%{reply, History, Req2, {Pid, empty}}
  end.

stream(Message, Req, State) ->
  [{<<"event">>, BinEvent}, {<<"data">>, Data}] = jsx:decode(Message),
  Event = erlang:binary_to_atom(BinEvent, utf8),
  erlang:display(Event),
  erlang:display(erlang:binary_to_list(Data)),
  case event({Event, Data}, Req, State) of
    {reply, {ReplyEvent, ReplyData}, NewReq, NewState} ->
      JsonReply = jsx:encode([{event, ReplyEvent}, {data, ReplyData}]),
      {reply, JsonReply, NewReq, NewState};
    Value -> Value
  end.

event({get, <<"history">>}, Req, {RoomPid, Nick}) ->
  History = room_server:get_history(RoomPid),
  {reply, History, Req, {RoomPid, Nick}};
  
event({nickname, Nick}, Req, {RoomPid, empty}) ->
  room_server:login_user(RoomPid, Nick),
  {ok, Req, {RoomPid, Nick}};

event({message, _Message}, Req, State = {_RoomPid, empty}) ->
  {ok, Req, State};
event({message, Message}, Req, State = {RoomPid, Nick}) ->
  gen_server:cast(RoomPid, {new_message, Nick, Message}),
  {ok, Req, State}.


info(Info, Req, State) ->
  JsonInfo = jsx:encode(Info),
  {reply, JsonInfo, Req, State}.

terminate(_Req, _TRef) ->
  ok.
