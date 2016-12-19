%% @author ydwiner and gaoliang
%% @doc @todo Add description to gprc_client.

-module(grpc_client).

%% ====================================================================
%% API functions
%% ====================================================================
-export([howto_single_conn/0, howto_long_conn/0]).
-compile(export_all).
-include("../include/gpb.hrl").

%% gRPC server parameters
-define(GRPC_SERVER_IP, "localhost").
-define(GRPC_SERVER_PORT, 50051).

%% Protocol Buffers parameters
-define(PROTO_FILE_NAME, helloworld).
-define(PROTO_FILE_SERVICE_NAME, 'Greeter').
-define(PROTO_FILE_SERVICE_FUNCTION, 'SayHello').
-define(PROTO_FILE_SERVICE_FUNCTION_PARAMETERS, [{name,"world"}]).

%% After how many times reconnect the gRPC connection
-define(RECONNECT_TIMES, 1000).

%% ====================================================================
%% Internal functions
%% ====================================================================

%% ----------
%% How to use
%% ----------
howto_single_conn() ->
	send_request(?GRPC_SERVER_IP, ?GRPC_SERVER_PORT, [
							{module, ?PROTO_FILE_NAME},
							{service,?PROTO_FILE_SERVICE_NAME},
							{function, ?PROTO_FILE_SERVICE_FUNCTION},
							{param, ?PROTO_FILE_SERVICE_FUNCTION_PARAMETERS}]).

howto_long_conn() ->
	%% long connection precondition
	lconnect_ets:start(),
	poolManager:start(),
	%% repeat call
	R = lconnect:post_time(?MODULE, ?GRPC_SERVER_IP, ?GRPC_SERVER_PORT, [
							{module, ?PROTO_FILE_NAME},
							{service,?PROTO_FILE_SERVICE_NAME},
							{function, ?PROTO_FILE_SERVICE_FUNCTION},
							{param, ?PROTO_FILE_SERVICE_FUNCTION_PARAMETERS}],
						   ?RECONNECT_TIMES),	% 1st
	R = lconnect:post_time(?MODULE, ?GRPC_SERVER_IP, ?GRPC_SERVER_PORT, [
							{module, ?PROTO_FILE_NAME},
							{service,?PROTO_FILE_SERVICE_NAME},
							{function, ?PROTO_FILE_SERVICE_FUNCTION},
							{param, ?PROTO_FILE_SERVICE_FUNCTION_PARAMETERS}],
						   ?RECONNECT_TIMES).	% 2nd

%% ----------
%% I/Fs
%% ----------
new(IP,Port) ->
	try
		h2_client:start_link(http, IP, Port)
	catch
		_:Reason ->
			{error, Reason, erlang:get_stacktrace()}
	end.

call(Pid,InterfaceParam) ->
	Module = proplists:get_value(module, InterfaceParam, null),
	Service = proplists:get_value(service,InterfaceParam, null),
	Fun = proplists:get_value(function,InterfaceParam, null),
	Param = proplists:get_value(param, InterfaceParam, ""),
	Option = proplists:get_value(option, InterfaceParam, []),
	call(Pid,Module,Service,Fun,Param,Option).

call(Pid,Module,Service,Fun,Param,Option) ->
	try
		TimeOut = proplists:get_value(timeout, Option, 30000),
		{RequestName,ResponseName} = get_msg_def(Module, Service, Fun),
		Request = makeRecordTuple(RequestName, Module:find_msg_def(RequestName), Param, []),
		Body = Module:encode_msg(Request),
		H2Path = get_interface_info(Module, Service, Fun),
		RequestHeader = makeH2Header([{path,H2Path} | Option]),
		Size = erlang:size(Body),
		RequestBody = <<0:8,Size:32,Body/binary>>,
		Response = hs_send_request(Pid, RequestHeader, RequestBody,TimeOut),
		{ok,parseResponse(Module,ResponseName,Response)}
	catch
		_:Reason ->
			{error, Reason, erlang:get_stacktrace()}
	end.

send_request(IP,Port,InterfaceParam) ->
	Module = proplists:get_value(module, InterfaceParam, null),
	Service = proplists:get_value(service,InterfaceParam, null),
	Fun = proplists:get_value(function,InterfaceParam, null),
	Param = proplists:get_value(param, InterfaceParam, ""),
	Option = proplists:get_value(option, InterfaceParam, []),
	send_request(IP,Port,Module,Service,Fun,Param,Option).

send_request(IP,Port,Module,Service,Fun,Param) ->
	send_request(IP,Port,Module,Service,Fun,Param,[]).

send_request(IP,Port,Module,Service,Fun,Param,Option) ->
	{ok,Pid} = new(IP,Port),
	Request = call(Pid,Module,Service,Fun,Param,Option),
	stop(Pid),
	Request.

stop(Pid) ->
	h2_client:stop(Pid).

makeH2Header(Option) ->
	Method = proplists:get_value(method, Option, "POST"),
	Scheme = proplists:get_value(scheme, Option, "http"),
	Path = proplists:get_value(path, Option, ""),
	Content_type = proplists:get_value(content_type, Option, "application/grpc"),
	Te = proplists:get_value(te, Option, "trailers"),
	[{<<":method">>,list_to_binary(Method)},{<<":scheme">>,list_to_binary(Scheme)},{<<":path">>,list_to_binary(Path)}
	 ,{<<"content-type">>,list_to_binary(Content_type)},{<<"te">>,list_to_binary(Te)}].

get_interface_info(Module,Service,Fun) ->
	lists:append(["/",atom_to_list(Module),".",atom_to_list(Service),"/",atom_to_list(Fun)]).

get_msg_def(Module,Service,Fun) ->
	{rpc,_,Request,Reply,_,_,_} = Module:find_rpc_def(Service,Fun),
	{Request,Reply}.

makeRecordTuple(RecordName,[],_,Result) ->
	list_to_tuple([RecordName | lists:reverse(Result)]);
makeRecordTuple(RecordName,RecordStru,DataList,Result) ->
	[Stru | RestStru] = RecordStru,
	{field,Name,_,_,_,_,_} = Stru,
	Data = 
		case lists:keyfind(Name, 1, DataList) of
			false ->
				undefine;
			{Name,Value} ->
				unicode:characters_to_binary(Value,utf8)
		end,
	makeRecordTuple(RecordName, RestStru, DataList, [Data | Result]).

parseResult([],_,Result) ->
	Result;
parseResult(RecordStru,DataList,Result) ->
	[Stru | ResStru] = RecordStru,
	{field,Name,_,_,Type,_,_} = Stru,
	[Data | RestList] = DataList,
	Value = transData(Type,Data),
	parseResult(ResStru,RestList,[{Name,Value}|Result]).

parseResponse(Module,ResponseName,Response) ->
	{Reuslt,{_,[ResultRes]}} = Response,
	case Reuslt of
		ok ->
			Size = erlang:size(ResultRes) - 5,
			<<_:5/binary,Body:Size/binary>> = ResultRes,
			[_|ResponseResult] = tuple_to_list(Module:decode_msg(Body,ResponseName)),
			parseResult(Module:find_msg_def(ResponseName), ResponseResult, []);
		error ->
			{error, ResultRes}
	end.

hs_send_request(CliPid,Headers,Body,TimeOut) ->
	StreamId = h2_connection:new_stream(CliPid),
	h2_connection:send_headers(CliPid, StreamId, Headers),
	h2_connection:send_body(CliPid,StreamId,Body),
	receive
		{'END_STREAM', StreamId} ->
			h2_connection:get_response(CliPid, StreamId)
	after TimeOut ->
		{error, {reply,[timeout]}}
	end.

transData(Type,Data) ->
	case Type of
		string ->
			Data;
		int32 ->
			integer_to_list(Data);
		int64 ->
			integer_to_list(Data);
		uint32 ->
			integer_to_list(Data);
		uint64 ->
			integer_to_list(Data);
		sint32 ->
			integer_to_list(Data);
		sint64 ->
			integer_to_list(Data);
		fixed32 ->
			integer_to_list(Data);
		fixed64 ->
			integer_to_list(Data);
		sfixed32 ->
			integer_to_list(Data);
		sfixed64 ->
			integer_to_list(Data);
		bool ->
			atom_to_list(Data);
		enum ->
			atom_to_list(Data);
		message ->
			atom_to_list(Data);
		bytes ->
			binary_to_list(Data)
	end.
