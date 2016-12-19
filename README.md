#gPRC Client for Erlang -- Fast version
*******************************

##DESCRIPTION
-------------
**This is a fast version of gRPC client implementation for the Erlang programming language.**  
**The so-called fast version is that this gRPC client has used fast http/2 and long connection.**

###Base protocol:
* [gRPC](http://www.grpc.io/ "gRPC")
* [Protocol Buffers](https://developers.google.com/protocol-buffers/docs/overview "Protocol Buffers")

###Dependence source code:
* [Fast erlang http/2 client](https://github.com/optd-dl/http2-client-erlang-fast "Fast erlang http/2 client")
* [Protocol Buffers for erlang](https://github.com/tomas-abrahamsson/gpb "Protocol Buffers for erlang")

###Author:
* **RongCapital(DaLian) information service Ltd.**

###Contact us:
* [yangdawei@rongcapital.cn](mailto:yangdawei@rongcapital.cn)
* [jinxin@rongcapital.cn](mailto:jinxin@rongcapital.cn)
* [gaoliang@rongcapital.cn](mailto:gaoliang@rongcapital.cn)

##HowTo
-------------------
***Refer to:***  
[src/grpc_client.erl](https://github.com/optd-dl/grpc-client-erlang-fast/blob/master/src/grpc_client.erl "grpc_client.erl")  
***e.g.***  
#####helloworld.proto
```protobuf
package helloworld;

// The greeting service definition.
service Greeter {
  // Sends a greeting
  rpc SayHello (HelloRequest) returns (HelloReply) {}
}

// The request message containing the user's name.
message HelloRequest {
  string name = 1;
}

// The response message containing the greetings
message HelloReply {
  string message = 1;
}
```
#####grpc_client.erl
```erlang
%% gRPC server parameters
-define(GRPC_SERVER_IP, "localhost").
-define(GRPC_SERVER_PORT, 50051).

%% Protocol Buffers parameters
-define(PROTO_FILE_NAME, helloworld).
-define(PROTO_FILE_SERVICE_NAME, 'Greeter').
-define(PROTO_FILE_SERVICE_FUNCTION, 'SayHello').
-define(PROTO_FILE_SERVICE_FUNCTION_PARAMETERS, [{name,"world"}]).

howto_single_conn() ->
	send_request(?GRPC_SERVER_IP, ?GRPC_SERVER_PORT, [
							{module, ?PROTO_FILE_NAME},
							{service,?PROTO_FILE_SERVICE_NAME},
							{function, ?PROTO_FILE_SERVICE_FUNCTION},
							{param, ?PROTO_FILE_SERVICE_FUNCTION_PARAMETERS}]).

%% After how many times reconnect the gRPC connection
-define(RECONNECT_TIMES, 1000).

howto_long_conn() ->
	%% long connection precondition
	lconnect_ets:start(),
	poolManager:start(),
	%% repeat call
	lconnect:post_time(?MODULE, ?GRPC_SERVER_IP, ?GRPC_SERVER_PORT, [
							{module, ?PROTO_FILE_NAME},
							{service,?PROTO_FILE_SERVICE_NAME},
							{function, ?PROTO_FILE_SERVICE_FUNCTION},
							{param, ?PROTO_FILE_SERVICE_FUNCTION_PARAMETERS}],
					   ?RECONNECT_TIMES),	% 1st
	lconnect:post_time(?MODULE, ?GRPC_SERVER_IP, ?GRPC_SERVER_PORT, [
							{module, ?PROTO_FILE_NAME},
							{service,?PROTO_FILE_SERVICE_NAME},
							{function, ?PROTO_FILE_SERVICE_FUNCTION},
							{param, ?PROTO_FILE_SERVICE_FUNCTION_PARAMETERS}],
					   ?RECONNECT_TIMES).	% 2nd
```

##Build
-------------------
$ ./rebar get-deps  
$ ./rebar compile  
$ ./deps/gpb/bin/protoc-erl -I. -o src deps/chatterbox/java-server/src/main/proto/helloworld.proto  
$ ./rebar compile

##Run
------------
***e.g.***
###Run Server -- Precondition -- Javal
$ cd deps/chatterbox && ./start-server.sh  
#####Notice
***The first running will take a long time, because need to download gradle and jars.***

###Run Client -- Erlang
$ ./rebar shell
```erlang
grpc_client:howto_single_conn().
```
***or***
```erlang
grpc_client:howto_long_conn().
```

###Use a new proto file
$ ./deps/gpb/bin/protoc-erl -I. -o src ${NEW_PROTO_FILE_PATH}  
$ ./rebar compile

##Dependencies
-------------------
***The following is the environment of author, may not be mandatory dependencies.***  

* Linux -- CentOS-7-x86_64-Everything-1503-01
* Erlang -- otp 18.1
* Java -- jdk-8u111-linux-x64
* Gradle -- gradle-2.13 (audo download in [start-server.sh](https://github.com/optd-dl/http2-client-erlang-fast/blob/master/start-server.sh "howto.erl"))
* Git -- git x86_64 1.8.3.1

