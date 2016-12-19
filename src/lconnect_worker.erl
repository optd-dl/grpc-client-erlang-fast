-module(lconnect_worker).

%% API
-export([start_link/1]).

%% gen_server callbacks
-export([init/1,
		 handle_call/3,
		 handle_cast/2,
		 handle_info/2,
		 terminate/2]).

-include("../include/lconnect_conf.hrl").

-record(information,{client :: any(),
					 module :: any(),
					 host :: list(),
					 port :: integer(),
					 time :: integer()}).

start_link(Arg) ->
	gen_server:start_link(?MODULE, Arg, []).

init([]) ->
	process_flag(trap_exit, true),
	State = #information{client = [], module = [], host = "", port = 0},
	{ok,State}.

handle_call({post,InterfaceParam}, _From, State = #information{client = [],module = Interface,host = Host, port = Port}) ->
	Client = 
		case Interface:new(Host, Port) of
			{ok,Client_1} -> Client_1;
			_ -> []
		end,
	case Client of
		[] -> {reply, {error,connect_faild}, State};
		_ -> 
			{_, Response} = Interface:call(Client,InterfaceParam),
			{reply,Response,State#information{client = Client}}
	end;

handle_call({post,InterfaceParam}, _From, State = #information{client = Client,host = Host,port = Port,module = Interface}) ->
	New_Client = 
		case erlang:is_process_alive(Client) of
			false -> {ok,Client_1} = Interface:new(Host,Port),
					 Client_1;
			true -> Client
		end,
	{_, Response} = Interface:call(New_Client,InterfaceParam),
	{reply, Response, State#information{client = New_Client}};

handle_call({post_time,InterfaceParam,ReconnectTime}, _From, State = #information{client = Client,host = Host,port = Port,module = Interface,time = Time}) ->
	{New_Client,New_Time} = 
		if Time >= ReconnectTime ->
			   Interface:stop(Client),
			   {ok,Client_1} = Interface:new(Host,Port),
			   {Client_1,0};
		   true ->
			   {Client,Time + 1}
		end,
	{_,Response} = Interface:call(New_Client,InterfaceParam),
	{reply,Response,State#information{client = New_Client, time = New_Time}};

handle_call({worker_init,{Interface,Host,Port}},_From,State) ->
	{Result,Client} = 
		case Interface:new(Host, Port) of
			{ok,Client1} -> 
				{ok,Client1};
			{error,Reason} ->
				{Reason,[]}
		end,
	{reply, Result,State#information{client = Client,module = Interface,host = Host, port = Port, time = 0}};

handle_call(_Request, _From, State) ->
	Reply = ok,
	{reply, Reply, State}.

handle_cast(clean,State = #information{client = Client,module = Interface}) ->
	Interface:stop(Client),
	{noreply,State#information{client = [], host = "", port = 0}};

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason,_State=#information{client = Client,module = Interface}) ->
	Interface:stop(Client),
	ok.
