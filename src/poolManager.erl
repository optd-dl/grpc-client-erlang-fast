%% @author ydwiner
%% @doc @todo Add description to poolManager.

-module(poolManager).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0,create/0,createPool/3,createSubPool/1,etsTimeFun/3]).
-include("../include/lconnect_conf.hrl").

%% ====================================================================
%% Internal functions
%% ====================================================================
start() ->
	register(poolServer, spawn(poolManager, create, [])),
	lconnect_ets:createNewTable(self(), ?POOLTABLE_NAME),
	poolServer ! {create_pool,self(),?POOL_DYN_NAME,?POOL_DYN_CONNECT_NUM,[]},
	lconnect_ets:setTableReleaseTime(?POOLTABLE_NAME, ?POOL_UPDATE_TIME).

create() ->
	receive
		{create_pool,_From,PoolName,NumCon,Option} ->
			lconnect:start_link(PoolName, NumCon, Option),
			_From ! done,
			create();
		{create_sub_pool,_From,Args} ->
			lconnect_process_lb:start(Args),
			_From ! done,
			create()
	end.

createPool(PoolName,NumCon,Option) ->
	poolServer ! {create_pool,self(),PoolName,NumCon,Option},
	receive
		done -> ok;
		_ -> error
	end.

createSubPool(Args) ->
	poolServer ! {create_sub_pool,self(),Args},
	receive
		done -> ok;
		_ -> error
	end.

etsTimeFun(TableName,Time,Fun) ->
	releaseTableData(TableName,Time,{first,first_key}, Fun).

releaseTableData(TableName,Time,{first,_},Fun) ->
	Key = ets:first(TableName),
	case Key of 
		'$end_of_table' ->
			done;
		Key ->
			case lconnect_ets:etsTableElementExist(TableName,Key,2) of 
				true ->
					Data_Time = ets:lookup_element(TableName,Key,2),
					Now_Time = erlang:system_time(milli_seconds),
					if Now_Time - Data_Time > Time ->
						   Next_Key = ets:next(TableName,Key),
						   Data = ets:lookup_element(TableName, Key, 3),
						   Fun(Data),
						   ets:delete(TableName,Key),
						   releaseTableData(TableName,Time,{next,Next_Key},Fun);
					   true ->
						   Next_Key = ets:next(TableName,Key),
						   releaseTableData(TableName,Time,{next,Next_Key},Fun)
					end;
				false ->
					faild
			end
	end;
releaseTableData(TableName,Time,{next,Key},Fun) ->
	case Key of 
		'$end_of_table' ->
			done;
		Key ->
			case lconnect_ets:etsTableElementExist(TableName,Key,2) of
				true ->
					Data_Time = ets:lookup_element(TableName,Key,2),
					Now_Time = erlang:system_time(milli_seconds),
					if Now_Time - Data_Time > Time ->
						   Next_Key = ets:next(TableName,Key),
						   Data = ets:lookup_element(TableName, Key, 3),
						   Fun(Data),
						   ets:delete(TableName,Key),
						   releaseTableData(TableName,Time,{next,Next_Key},Fun);
					   true ->
						   Next_Key = ets:next(TableName,Key),
						   releaseTableData(TableName,Time,{next,Next_Key},Fun)
					end;
				false ->
					faild
			end	
	end.
