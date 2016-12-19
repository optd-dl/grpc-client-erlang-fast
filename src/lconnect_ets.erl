-module(lconnect_ets).
-export([start/0,createtable/3,createNewTable/2,createNewTable/3,insertDatas/3,insertData/3,
        etsTableIsExist/1,etsTableKeyIsExist/2,deleteTable/1,deleteData/2,deleteAllData/1,updateData/4,
		getDataFun/4,getData/2,getData/3,listen/3,listen/2,releaseData/0,
		setAutoReleaseParam/1,setAutoOutpuParam/5,stopAutoOutput/1,setConfig/0,
		addTableToReleaseList/2,deleteTableFromReleaseList/1,insertDataFun/3,
		insertEtsData/2,setTableReleaseTime/2,tableSizeListen/2,
		merge_to_tuple/2,find/2,compare/2,makeData/2,getTableSize/1,etsTableElementExist/3,releaseTableData/3]).

-include("../include/ms_transform.hrl").

start() ->
	Time = erlang:system_time(milli_seconds),
	ConfigListPid = spawn(lconnect_ets,createtable,[self(),configList,[set,public,named_table,{keypos,1}]]),
	TableListPid = spawn(lconnect_ets,createtable,[self(),tableList,[set,public,named_table,{keypos,1}]]),
	AutoOutputConfigListPid = spawn(lconnect_ets,createtable,[self(),autoOutputConfigList,[set,public,named_table,{keypos,1}]]),
	ListenProcessId = spawn(lconnect_ets,listen,[10 * 60 * 1000,releaseData,[]]),
	SetConfigProcessId = spawn(lconnect_ets,setConfig,[]),
	receive
		{tableList,table_create} ->
	    lconnect_ets:insertEtsData(tableList,[{tableList,Time,TableListPid,0},{configList,Time,ConfigListPid,0},{autoOutputConfigList,Time,AutoOutputConfigListPid,0}])
	end,
	receive
		{configList,table_create} ->
		lconnect_ets:insertDatas(configList,[list_process_id],[ListenProcessId]),
		lconnect_ets:insertDatas(configList,[auto_releaseData_param],[[10 * 60 * 1000]]),
		lconnect_ets:insertDatas(configList,[setConfig_process_id],[SetConfigProcessId])
	end,
	success.

setConfig() ->
	receive
		{insert_release_tablelist,TableName,Falg_Time} -> 
		   case lconnect_ets:etsTableKeyIsExist(tableList,TableName) of
			  false ->
			     go_on;
			  true ->
			    ets:update_element(tableList,TableName,{4,Falg_Time}),
				case lconnect_ets:etsTableKeyIsExist(configList,release_tablelist) of 
				 false ->
				   lconnect_ets:insertDatas(configList,[release_tablelist],[[TableName]]);
				 true ->
				   lconnect_ets:insertDatas(configList,[release_tablelist],[[TableName | ets:lookup_element(configList,release_tablelist,3)]])
				end
			end;
		{delete_release_tablelist,TableList} ->
		    case lconnect_ets:etsTableKeyIsExist(configList,release_tablelist) of
			true ->
			   List = lconnect_ets:getData(configList,release_tablelist,3),
			   NewList = List -- TableList,
			   lconnect_ets:insertDatas(configList,[release_tablelist],[NewList]);
			false ->
			   not_exit
			end;
		{set_auto_releaseData_param,Do_Time} ->
		    case lconnect_ets:etsTableElementExist(configList,list_process_id,3) of 
			    true ->
				  PID = lconnect_ets:getData(configList,list_process_id,3),
				  PID ! release,
				  lconnect_ets:insertDatas(configList,[auto_releaseData_param],[Do_Time]),
				  ListenProcessId = spawn(lconnect_ets,listen,[Do_Time,releaseData,[]]),
				  lconnect_ets:insertDatas(configList,[list_process_id],[ListenProcessId])
			end;
		{set_table_release_time,TableName,Flag_Time} ->
		    case lconnect_ets:etsTableKeyIsExist(tableList,TableName) of 
			   true ->
			       ets:update_element(tableList,TableName,{4,Flag_Time});
			   false ->
			      go_on
			end	   
	end,
	setConfig().

-spec listen(integer(),atom(),list()) -> any().
listen(Time,Fun,ParamList) ->
	erlang:send_after(Time,self(),message),
	receive
		message ->
		   spawn(lconnect_ets,Fun,ParamList),
		   lconnect_ets:listen(Time,Fun,ParamList);
		release ->
		    release
	end.

-spec listen(integer(),fun()) -> any().	
listen(Time,Fun) ->
	erlang:send_after(Time,self(),message),
	receive
		message ->
		   spawn(Fun),
		   lconnect_ets:listen(Time,Fun);
		release ->
		    release
	end.

merge_to_tuple(List1,List2) ->
	case lconnect_ets:compare(List1, List2) of
		false ->
			false;
		true ->
			lists:zip(List1, List2)
	end.

-spec find(any(),list()) -> atom().
find(Name,TableList) ->
	lists:member(Name,TableList).
	
-spec compare(list(),list()) -> atom().
compare(List1,List2) ->
	if erlang:length(List1) == erlang:length(List2) ->
		true;
	true ->
	    false
	end.

-spec makeData(list(),list()) -> any().	
makeData([],[]) ->
	[];
makeData(Keys,DataList) ->
	[FirstKey | RestKeys] = Keys,
	[FirstData | RestData] = DataList,
	Time = erlang:system_time(milli_seconds),
	Contect = {FirstKey,Time,FirstData},
	[Contect | lconnect_ets:makeData(RestKeys,RestData)].


-spec getTableSize(atom()) -> integer().		
getTableSize(TableName) ->
	ets:info(TableName,size).

-spec etsTableIsExist(atom()) -> atom().	
etsTableIsExist(TableName) ->
	lconnect_ets:find(TableName,ets:all()).

-spec etsTableKeyIsExist(atom(),atom()) -> atom().		
etsTableKeyIsExist(TableName,Key) ->
	ets:member(TableName,Key).

-spec etsTableElementExist(atom(),atom(),integer()) -> atom().	
etsTableElementExist(TableName,Key,Pos) ->
	case lconnect_ets:etsTableIsExist(TableName) of 
		true ->
		   case etsTableKeyIsExist(TableName,Key) of 
		     true ->
			    Datas = ets:lookup(TableName,Key),
				[Data | _] = Datas,
				Length = erlang:length(tuple_to_list(Data)),
				if Length < Pos ->
				    false;
				true ->
				    true
				end;	
			 false ->
			   false
		   end;
		false ->
		  false
	end.
	

createtable(PID,TableName,ParamList)->
	case lconnect_ets:etsTableIsExist(TableName) of 
	  false ->
		ets:new(TableName,ParamList),
		PID ! {TableName,table_create};
	  true -> 
		 PID ! {TableName,table_has_created}
	end,
	receive
		release ->
		  PID ! {TableName,table_release}
	end.


-spec createNewTable(pid(), atom()) -> atom().
createNewTable(PID,TableName) ->
    TablePID = spawn(lconnect_ets,createtable,[self(),TableName,[set,public,named_table,{keypos,1}]]),
	receive
		{TableName,table_create} ->
	      Time = erlang:system_time(milli_seconds),
	      lconnect_ets:insertEtsData(tableList,[{TableName,Time,TablePID,0}]),
		  PID ! {TableName,success},
		  success;
		{TableName,table_has_created} ->
		  PID ! {TableName,table_exist},
		  TablePID ! release,
		  table_exist
	end.
	
createNewTable(PID,TableName,ParamList) ->
	TablePID = spawn(lconnect_ets,createtable,[self(),TableName,ParamList]),
	receive
		{TableName,table_create} ->
	      Time = erlang:system_time(milli_seconds),
	      lconnect_ets:insertEtsData(tableList,[{TableName,Time,TablePID,0}]),
		  PID ! {TableName,success},
		  success;
		{TableName,table_has_created} ->
		  PID ! {TableName,table_exist},
		  table_exist
	end.

-spec insertEtsData(atom(), tuple() | list()) -> any().
insertEtsData(TableName,DataList) ->
	ets:insert(TableName,DataList).

-spec insertDatas(atom(), list(),list()) -> any().
insertDatas(TableName,Keys,Datas) ->
	case lconnect_ets:compare(Keys,Datas) of 
		true ->
		  case lconnect_ets:etsTableIsExist(TableName) of true ->
		        ets:insert(TableName,lconnect_ets:makeData(Keys,Datas));
		  false -> 
		    notable
	     end;
	    false ->
		  faild
	 end.

insertData(TableName,Key,Data) ->
	Time = erlang:system_time(milli_seconds),
	ets:insert(TableName, {Key,Time,Data}).
		
										   

-spec deleteTable(atom()) -> atom().
deleteTable(TableName) ->
	case etsTableKeyIsExist(tableList,TableName) of
	  true ->
		    TablePID = lconnect_ets:getData(tableList,TableName,3),
			TablePID ! release,
			ets:delete(tableList,TableName),
			success;
	  false ->
	    table_not_exit
	end.

-spec deleteData(atom(),atom()) -> atom().
deleteData(TableName,Key) ->
	case etsTableKeyIsExist(tableList,TableName) of
		true ->
		    ets:delete(TableName,Key),
			success;
		false ->
		    table_not_exit_or_no_access
	end.


-spec deleteAllData(atom()) ->atom().
deleteAllData(TableName) ->
	ets:delete_all_objects(TableName).

-spec updateData(atom(),atom(),list(),list()) -> any().
updateData(TableName,Key,Poses,Values) ->
	case lconnect_ets:compare(Poses, Values) of 
		false ->
			false;
		true ->
			MaxPos = lists:max(Poses),
			case lconnect_ets:etsTableElementExist(TableName, Key, MaxPos) of
				false ->
					false;
				true ->
                    ets:update_element(TableName, Key, lconnect_ets:merge_to_tuple(Poses, Values)),
                    true
             end
	end.

-spec getDataFun(atom(),atom(),fun(),any()) -> any().	
getDataFun(TableName,Key,Fun,ParamList) ->
	case lconnect_ets:etsTableKeyIsExist(TableName,Key) of false ->
		Data = Fun(ParamList),
		case Data of
			couchbase_error ->
				insertData(TableName,Key,null),
				null;
			Data ->
          		insertData(TableName,Key,Data),
				Data
		end;
	true ->
			   [{_,Data_Time,Data}] = ets:lookup(TableName,Key),
			   Flag_Time = case Data of 
			                   null -> 60000;
							   Data -> ets:lookup_element(tableList,TableName,4) end,
			   Now_Time = erlang:system_time(milli_seconds),
			   if Flag_Time == 0 ->				
		           Data;
			   true ->
			       if Now_Time - Data_Time < Flag_Time ->
				      Data;
				   true ->
				      New_Data = Fun(ParamList),
					  case New_Data of
						  couchbase_error ->
							  insertData(TableName,Key,Data),
							  Data;
						  New_Data ->
					  		  insertData(TableName,Key,New_Data),
		              		  New_Data
					  end
					end
				end
	end.

insertDataFun(TableName,Key,DataList) ->
	SizeFunPid = lconnect_ets:getData(autoOutputConfigList,TableName,5),
	case SizeFunPid of
		0 ->
			go_on;
		SizeFunPid ->
			SizeFunPid ! {self(),size_do},
		receive
            go_on ->
                go_on
        end
	end,
	%insertEtsData(TableName,DataList).
    lconnect_ets:insertData(TableName, Key, DataList).

-spec getData(atom(),atom()) -> any().	
getData(TableName,Key) ->
   ets:lookup(TableName, Key).

-spec getData(atom(),atom(),integer()) -> any().
getData(TableName,Key,Pos) ->
	case lconnect_ets:etsTableElementExist(TableName,Key,Pos) of
		true ->
		  Data = ets:lookup_element(TableName,Key,Pos),
		  Data;
		false ->
		  []
	end.

-spec releaseData() -> any().
releaseData() ->
	case lconnect_ets:etsTableElementExist(configList,release_tablelist,3) of
	 true ->
		Release_Table_List = ets:lookup_element(configList,release_tablelist,3),
		lconnect_ets:createNewTable(self(),tempTable),
		F = fun(TableName) ->
			case lconnect_ets:etsTableIsExist(TableName) of
				false ->
				  case lconnect_ets:etsTableElementExist(tempTable,deleteReleaseConfig,3) of
					true ->
					   Datas = lconnect_ets:getData(tempTable,deleteReleaseConfig,3),
				       lconnect_ets:insertData(tempTable,[deleteReleaseConfig],[[TableName | Datas]]);
					false ->
					    lconnect_ets:insertData(tempTable,[deleteReleaseConfig],[[TableName]])
				  end;
				true ->
				   Time = lconnect_ets:getData(tableList,TableName,4),
				   if Time == 0 ->
				      go_on;
					true ->
				      lconnect_ets:releaseTableData(TableName,Time,{first,firstKey})
				   end
			end
		end,
		lists:foreach(F,Release_Table_List),
		case lconnect_ets:etsTableElementExist(tempTable,deleteReleaseConfig,3) of 
			true ->
			  Deleted = lconnect_ets:getData(tempTable,deleteReleaseConfig,3),
			  SetConfigPID = lconnect_ets:getData(configList,setConfig_process_id,3),
		      SetConfigPID ! {delete_release_tablelist,Deleted};
			false ->
			  go_on
		end,
		lconnect_ets:deleteTable(tempTable);
	false ->
	   no_config
	end,
	done
.

-spec releaseTableData(atom(),integer(),tuple()) -> any().
releaseTableData(TableName,Time,{first,_}) ->
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
		     ets:delete(TableName,Key),
			lconnect_ets:releaseTableData(TableName,Time,{next,Next_Key});
		  true ->
		     Next_Key = ets:next(TableName,Key),
			 lconnect_ets:releaseTableData(TableName,Time,{next,Next_Key})
		  end;
		    false ->
			  faild
		  end
	end;
releaseTableData(TableName,Time,{next,Key}) ->
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
		     ets:delete(TableName,Key),
			 lconnect_ets:releaseTableData(TableName,Time,{next,Next_Key});
		   true ->
		     Next_Key = ets:next(TableName,Key),
			 lconnect_ets:releaseTableData(TableName,Time,{next,Next_Key})
		   end;
		    false ->
			 faild
		end	
	end.

-spec setAutoReleaseParam(integer()) -> any().
setAutoReleaseParam(Do_Time) ->
	SetConfigPID = lconnect_ets:getData(configList,setConfig_process_id,3),
	SetConfigPID ! {set_auto_releaseData_param,Do_Time},
	success
.

-spec setTableReleaseTime(atom(),integer()) -> atom().
setTableReleaseTime(TableName,Flag_Time) ->
	SetConfigPID = lconnect_ets:getData(configList,setConfig_process_id,3),
	SetConfigPID ! {set_table_release_time,TableName,Flag_Time},
	success.

-spec addTableToReleaseList(atom(),integer()) -> any().
addTableToReleaseList(TableName,Flag_Time) ->
	case lconnect_ets:etsTableIsExist(TableName) of
		true ->
		   SetConfigPID = lconnect_ets:getData(configList,setConfig_process_id,3),
		   SetConfigPID ! {insert_release_tablelist,TableName,Flag_Time},
		   sucess;
		false ->
		   table_not_exit
	end.

-spec deleteTableFromReleaseList(atom()) -> any().
deleteTableFromReleaseList(TableName) ->
	 SetConfigPID = lconnect_ets:getData(configList,setConfig_process_id,3),
	 SetConfigPID ! {delete_release_tablelist,[TableName]},
	 success.

-spec setAutoOutpuParam(atom(),integer(),integer(),fun(),fun()) -> any().
setAutoOutpuParam(TableName,Time,Size,Fun,SizeFun) ->
	SizeFunPid = 
	case lconnect_ets:etsTableKeyIsExist(autoOutputConfigList,TableName) of
		true ->
			SizePID = lconnect_ets:getData(autoOutputConfigList,TableName,5),
			SizePID ! release,
			case Size of
				0 ->
					0;
				Size ->
					spawn(lconnect_ets, tableSizeListen, [TableName,SizeFun])
			end;				 
		false ->
			case Size of
				0 ->
					0;
				Size ->
					spawn(lconnect_ets, tableSizeListen, [TableName,SizeFun])
			end
	end,
	if Time == 0 ->
	    lconnect_ets:insertEtsData(autoOutputConfigList,{TableName,Time,Size,0,SizeFunPid}),
	    go_on;
	true ->
	   F = fun() ->
		  case lconnect_ets:etsTableIsExist(TableName) of
			true ->
			  Now_Time = erlang:system_time(nano_seconds) - 5000000,
			  Data = ets:select(TableName, ets:fun2ms(fun({_,X,Z}) when X * 1000000 < Now_Time -> Z end)),
              ets:select_delete(TableName,ets:fun2ms(fun({_,X,_}) when X * 1000000 < Now_Time -> true end)),
			  Fun(Data);
		    false ->
			  table_not_exist
			end
	   end,
	   case lconnect_ets:etsTableKeyIsExist(autoOutputConfigList,TableName) of
		  true ->
		     TimePID = lconnect_ets:getData(autoOutputConfigList,TableName,4),
			 TimePID ! release,
			 NewTimePID = spawn(lconnect_ets,listen,[Time,F]),
			 lconnect_ets:insertEtsData(autoOutputConfigList,{TableName,Time,Size,NewTimePID,SizeFunPid});
		  false ->
		     NewTimePID = spawn(lconnect_ets,listen,[Time,F]),
			 lconnect_ets:insertEtsData(autoOutputConfigList,{TableName,Time,Size,NewTimePID,SizeFunPid})
		end
	end,
	SetConfgPid = lconnect_ets:getData(configList,setConfig_process_id,3),
	SetConfgPid ! {{delete_release_tablelist,[TableName]}}.

-spec stopAutoOutput(atom()) -> any().
stopAutoOutput(TableName) ->
	case lconnect_ets:etsTableKeyIsExist(autoOutputConfigList,TableName) of
		true ->
			TimePID = lconnect_ets:getData(autoOutputConfigList,TableName,4),
			SizePID = lconnect_ets:getData(autoOutputConfigList,TableName,5),
			case TimePID of 
				0 ->
				  go_on;
			   TimePID ->
				 TimePID ! release
			end,
			case SizePID of
				0 ->
					go_on;
				SizePID ->
					SizePID ! release
			end,
			ets:delete(autoOutputConfigList,TableName),
			SetConfigPid = lconnect_ets:getData(configList,setConfig_process_id,3),
			SetConfigPid ! {insert_release_tablelist,TableName,10 * 60 * 1000};
		false ->
		  no_table_config
	end
.

-spec tableSizeListen(atom(),fun()) -> atom().
tableSizeListen(TableName,Fun) ->
     receive
        {PID,size_do} ->
 		   Size = lconnect_ets:getData(autoOutputConfigList,TableName,3),
		   if Size == 0 ->
		      PID ! go_on;
		   true ->
		      Now_Size = lconnect_ets:getTableSize(TableName),
			  if Now_Size < Size ->
			     PID ! go_on;
			  true ->
				 Now_Time = erlang:system_time(nano_seconds) - 5000000,
				 Data = ets:select(TableName, ets:fun2ms(fun({_,X,Z}) when X * 1000000 < Now_Time -> Z end)),
                 ets:select_delete(TableName,ets:fun2ms(fun({_,X,_}) when X * 1000000 < Now_Time -> true end)),
				 F = fun() ->
					Fun(Data)
				 end,
				 spawn(F),
			     PID ! go_on
			  end
			 end,
			 lconnect_ets:tableSizeListen(TableName,Fun);
		 {Pid,size} ->
			 Size = lconnect_ets:getData(autoOutputConfigList,TableName,3),
             Pid ! Size,
			 lconnect_ets:tableSizeListen(TableName,Fun);
		  release ->
              release
	end.
