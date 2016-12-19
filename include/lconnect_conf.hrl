-define(MODULE_NAME, roprpc_thrift).
-define(FUNCTION_NAME, call).
-define(POOLTABLE_NAME, t_pooltable).
-define(POOL_CLEAN_TIME, 15 * 60 * 1000).
-define(POOL_UPDATE_TIME, 5 * 60 * 1000).
-define(POOL_CONNECT_NUM,50).
-define(POOL_MAX_NUM,200).



%-----------------------------------------------------
-define(POOL_DYN_NAME,rpc_dynamic_pool).
-define(POOL_DYN_CONNECT_NUM,1000).
