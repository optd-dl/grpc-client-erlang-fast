%% @author ydwiner
%% @doc @todo Add description to rpcProcessLb.


-module(lconnect_process_lb).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/1,checkout/1,checkin/2,startCleanTimer/0]).

-export([init/1,
		 handle_call /3,
		 terminate/2]).

-record(process_info,{process_list :: list(),
					  interface ::module(),
					  ip :: string(),
					  port :: integer()}).

-include("../include/lconnect_conf.hrl").

%% ====================================================================
%% Internal functions
%% ====================================================================

start(Args) ->
	gen_server:start_link(?MODULE, Args, []).

init([Interface,IP,Port]) ->
	State = #process_info{process_list = [],interface = Interface, ip = IP, port = Port},
	lconnect_ets:insertData(?POOLTABLE_NAME, {IP,Port}, self()),
	spawn(?MODULE, startCleanTimer, []),
	{ok,State}
.

terminate(_Reason, _State = #process_info{process_list = List}) ->
	clean(List),
	ok.

handle_call(checkout,_From,State = #process_info{process_list = [],interface = Interface,ip = IP,port = Port}) ->
	Pid = poolboy:checkout(?POOL_DYN_NAME,false),
	case Pid of
		full ->
			{reply,full,State};
		_ ->
			gen_server:call(Pid, {worker_init,{Interface,IP,Port}}, infinity),
			{reply,Pid,State}
	end;

handle_call(checkout,_From,State = #process_info{process_list = List}) ->
	[Pid | Rest] = List,
	{reply, Pid, State#process_info{process_list = Rest}};

handle_call({checkin,Pid},_From,State = #process_info{process_list = List}) ->
	{reply,ok,State#process_info{process_list = [Pid | List]}}.

clean([]) ->
	ok;
clean(List) ->
	[Pid | Rest] = List,
	gen_server:cast(Pid, clean),
	poolboy:checkin(?POOL_DYN_NAME,Pid),
	clean(Rest).

checkout(Name) ->
	{Interface,IP,Port} = Name,
	F = fun([]) -> couchbase_error end,
	case lconnect_ets:getDataFun(?POOLTABLE_NAME,{IP,Port},F,[]) of
		null ->
			poolManager:createSubPool([Interface,IP,Port]),
			checkout(Name);
		Pid ->
			gen_server:call(Pid, checkout, infinity)
	end.

checkin(Name,Worker) ->
	case lconnect_ets:getData(?POOLTABLE_NAME, Name, 3) of
		[] -> 
			clean([Worker]);
		Pid ->
			gen_server:call(Pid, {checkin,Worker}, infinity)
	end.

startCleanTimer() ->
	erlang:send_after(?POOL_CLEAN_TIME, self(), clean),
	receive
		clean ->
			poolManager:etsTimeFun(?POOLTABLE_NAME, ?POOL_CLEAN_TIME, fun stopServer/1),
			startCleanTimer()
	end.

stopServer(Pid) ->
	gen_server:stop(Pid).
