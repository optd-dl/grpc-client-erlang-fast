-module(lconnect).
-include("../include/lconnect_conf.hrl").
-export([start_link/3, stop/1,post/4,post_time/5]).

start_link(PoolName, NumCon, []) ->
	SizeArgs = [{size, NumCon},
				{max_overflow, 0}],
	PoolArgs = [{name, {local, PoolName}},
				{worker_module, lconnect_worker}] ++ SizeArgs,
	WorkerArgs = [],
	poolboy:start_link(PoolArgs, WorkerArgs);
start_link(PoolName, NumCon, Option) ->
	SizeArgs = [{size, NumCon},
				{max_overflow, 0}],
	PoolArgs = [{name, {local, PoolName}},
				{worker_module, lconnect_worker}] ++ SizeArgs,
	WorkerArgs = Option,
	poolboy:start_link(PoolArgs, WorkerArgs).

stop(PoolPid) ->
	poolboy:stop(PoolPid).

post(Interface,IP,Port,InterfaceParam) ->
	case lconnect_process_lb:checkout({Interface,IP,Port}) of
		full ->
			try 
				Interface:send_request(IP,Port,InterfaceParam)
			catch
				_:Reason ->
					{error,Reason,erlang:get_stacktrace()}
			end;
		Worker when is_pid(Worker) ->
			try 
				gen_server:call(Worker, {post,InterfaceParam}, 30 * 1000)
			catch
				_:Reason1 ->
					{error,Reason1,erlang:get_stacktrace()}
			after
				lconnect_process_lb:checkin({IP,Port},Worker)
			end 
	end. 

post_time(Interface,IP,Port,InterfaceParam,ReconnectTime) ->
	case lconnect_process_lb:checkout({Interface,IP,Port}) of
		full ->
			try 
				Interface:send_request(IP,Port,InterfaceParam)
			catch
				_:Reason ->
					{error,Reason,erlang:get_stacktrace()}
			end;
		Worker when is_pid(Worker) ->
			try 
				gen_server:call(Worker, {post_time,InterfaceParam,ReconnectTime}, 30 * 1000)
			catch
				_:Reason1 ->
					{error,Reason1,erlang:get_stacktrace()}
			after
				lconnect_process_lb:checkin({IP,Port},Worker)
			end 
	end.
