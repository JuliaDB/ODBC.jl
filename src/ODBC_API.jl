#ODBC API Function Definitions
#By Jacob Quinn, 2013
#In general, the ODBC functions are implemented to mirror the C header files (sql.h,sqlext.h,sqltypes.h,sqlucode.h)
#A few liberties are taken in utliizing standard Julia functions and idioms
#Format:
 #function name
 #URL reference
 #short function description
 #valid const definitions
 #relevant notes
 #working and tested status
 #function definition code

#Contents
 #Macros and Utility Functions
 #Handle Functions
 #Connection Functions
 #Resultset Metadata Functions
 #Query Functions
 #Resultset Retrieval Functions
 #DBMS Meta Functions
 #Error Handling and Diagnostics

#### Macros and Utility Functions ####

# MULTIROWFETCH sets the default rowset fetch size
# used in retrieving resultset blocks from queries
const MULTIROWFETCH = 65535

# success codes
const SQL_SUCCESS           = int16(0)
const SQL_SUCCESS_WITH_INFO = int16(1)

# error codes
const SQL_ERROR             = int16(-1)
const SQL_INVALID_HANDLE    = int16(-2)

# status codes
const SQL_STILL_EXECUTING   = int16(2)
const SQL_NO_DATA           = int16(100)

const RETURN_VALUES = [SQL_ERROR   => "SQL_ERROR",
                       SQL_NO_DATA => "SQL_NO_DATA",
                       SQL_INVALID_HANDLE  => "SQL_INVALID_HANDLE",
                       SQL_STILL_EXECUTING => "SQL_STILL_EXECUTING"]

#Macros to to check if a function returned a success value or not; used with 'if' statements
#e.g. if @SUCCEEDED SQLDisconnect(dbc) print("Disconnected successfully") end
#ret_lu takes a function's return code and returns a text version by looking up its value in the RETURN_VALUES dict (defined above)
function ret_lu(ret)
    return get(RETURN_VALUES,ret,"SQL_DEFAULT_ERROR")
end

macro SUCCEEDED(func)
    global ret = ret_lu(func)
    :( return_code = $func; (return_code == SQL_SUCCESS || return_code == SQL_SUCCESS_WITH_INFO) ? true : false )
end

macro FAILED(func)
    global ret = ret_lu(func)
    :( return_code = $func; (return_code != SQL_SUCCESS && return_code != SQL_SUCCESS_WITH_INFO) ? true : false )
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms712400(v=vs.85).aspx
function SQLDrivers(env::Ptr{Void},
                    driver_desc::Array{Uint8,1},
                    desc_length::Array{Int16,1},
                    driver_attr::Array{Uint8,1},
                    attr_length::Array{Int16,1})
    @windows_only begin
        ret = ccall((:SQLDrivers, odbc_dm), stdcall, Int16,
                    (Ptr{Void}, Int16, Ptr{Uint8},
                    Int16, Ptr{Int16}, Ptr{Uint8}, Int16, Ptr{Int16}),
                    env, SQL_FETCH_NEXT, driver_desc, length(driver_desc),
                    desc_length, driver_attr, length(driver_attr), attr_length)
    end
    @unix_only begin
        ret = ccall((:SQLDrivers, odbc_dm), Int16,
                    (Ptr{Void}, Int16, Ptr{Uint8},
                     Int16, Ptr{Int16}, Ptr{Uint8}, Int16, Ptr{Int16}),
                    env, SQL_FETCH_NEXT, driver_desc, length(driver_desc),
                    desc_length, driver_attr, length(driver_attr), attr_length)
    end
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711004(v=vs.85).aspx
function SQLDataSources(env::Ptr{Void},
                        dsn_desc::Vector{Uint8},
                        desc_length::Array{Int16,1},
                        dsn_attr::Array{Uint8,1},
                        attr_length::Array{Int16,1})
    @windows_only begin
        ret = ccall((:SQLDataSources, odbc_dm), stdcall, Int16,
                    (Ptr{Void}, Int16, Ptr{Uint8}, Int16,
                     Ptr{Int16}, Ptr{Uint8}, Int16, Ptr{Int16}),
                    env, SQL_FETCH_NEXT, dsn_desc, length(dsn_desc),
                    desc_length, dsn_attr, length(dsn_attr), attr_length)
    end
    @unix_only begin
        ret = ccall((:SQLDataSources, odbc_dm), Int16,
                    (Ptr{Void}, Int16, Ptr{Uint8}, Int16,
                     Ptr{Int16}, Ptr{Uint8}, Int16, Ptr{Int16}),
                    env, SQL_FETCH_NEXT, dsn_desc, length(dsn_desc),
                    desc_length, dsn_attr, length(dsn_attr), attr_length)
    end
    return ret
end

#### Handle Functions ####

# SQLAllocHandle
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms712455(v=vs.85).aspx
# Description: allocates an environment, connection, statement, or descriptor handle
# Valid handle types
const SQL_HANDLE_ENV  = int16(1)
const SQL_HANDLE_DBC  = int16(2)
const SQL_HANDLE_STMT = int16(3)
const SQL_HANDLE_DESC = int16(4)
const SQL_NULL_HANDLE = C_NULL

#Status: Tested on Windows, Linux, Mac 32/64-bit
function SQLAllocHandle(handletype::Int16, parenthandle::Ptr{Void}, handle::Array{Ptr{Void},1})
    @windows_only begin
        ret = ccall((:SQLAllocHandle, odbc_dm), stdcall, Int16,
                    (Int16, Ptr{Void}, Ptr{Void}),
                    handletype, parenthandle, handle)
    end
    @unix_only begin
        ret = ccall((:SQLAllocHandle, odbc_dm), Int16,
                    (Int16, Ptr{Void}, Ptr{Void}),
                    handletype, parenthandle, handle)
    end
    return ret
end

# SQLFreeHandle
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms710123(v=vs.85).aspx
# Description: frees resources associated with a specific environment, connection, statement, or descriptor handle
# See SQLAllocHandle for valid handle types
# Status: Tested on Windows, Linux, Mac 32/64-bit
function SQLFreeHandle(handletype::Int16,handle::Ptr{Void})
    @windows_only begin
        ret = ccall((:SQLFreeHandle, odbc_dm), stdcall, Int16,
                    (Int16, Ptr{Void}), handletype, handle)
    end
    @unix_only begin
        ret = ccall((:SQLFreeHandle, odbc_dm), Int16,
                    (Int16, Ptr{Void}), handletype, handle)
    end
    return ret
end

# SQLSetEnvAttr
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms709285(v=vs.85).aspx
# Description: sets attributes that govern aspects of environments
# Valid attributes; valid values for attribute are indented
const SQL_ATTR_CONNECTION_POOLING = 201
const SQL_CP_OFF = uint(0)
const SQL_CP_ONE_PER_DRIVER = uint(1)
const SQL_CP_ONE_PER_HENV = uint(2)
const SQL_CP_DEFAULT = SQL_CP_OFF
const SQL_ATTR_CP_MATCH = 202
const SQL_CP_RELAXED_MATCH = uint(1)
const SQL_CP_STRICT_MATCH = uint(0)
const SQL_ATTR_ODBC_VERSION = 200
const SQL_OV_ODBC2 = 2
const SQL_OV_ODBC3 = 3
const SQL_ATTR_OUTPUT_NTS = 10001
const SQL_TRUE = 1
const SQL_FALSE = 0

#Status: Tested on Windows, Linux, Mac 32/64-bit
function SQLSetEnvAttr{T<:Union(Int,Uint)}(env_handle::Ptr{Void}, attribute::Int, value::T)
    @windows_only begin
        ret = ccall((:SQLSetEnvAttr, odbc_dm), stdcall, Int16,
                    (Ptr{Void}, Int, T, Int), env_handle, attribute, value, 0)
    end
    @unix_only begin
        ret = ccall((:SQLSetEnvAttr, odbc_dm), Int16,
                    (Ptr{Void}, Int, T, Int), env_handle, attribute, value, 0)
    end
    return ret
end

# SQLGetEnvAttr
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms709276(v=vs.85).aspx
# Description: returns the current setting of an environment attribute
# Valid attributes: See SQLSetEnvAttr
# Status:
function SQLGetEnvAttr(env::Ptr{Void},attribute::Int,value::Array{Int,1},bytes_returned::Array{Int,1})
    @windows_only begin
        ret = ccall((:SQLGetEnvAttr, odbc_dm), stdcall, Int16,
                    (Ptr{Void}, Int, Ptr{Int}, Int, Ptr{Int}),
                    env, attribute, value, 0, bytes_returned)
    end
    @unix_only begin
        ret = ccall((:SQLGetEnvAttr, odbc_dm), Int16,
                    (Ptr{Void}, Int, Ptr{Int}, Int, Ptr{Int}),
                    env, attribute, value, 0, bytes_returned)
    end
    return ret
end

# SQLSetConnectAttr
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms713605(v=vs.85).aspx
# Description: sets attributes that govern aspects of connections.
# Valid attributes
const SQL_ATTR_ACCESS_MODE = 101
const SQL_MODE_READ_ONLY = uint(1)
const SQL_MODE_READ_WRITE = uint(0)
#const SQL_ATTR_ASYNC_DBC_EVENT
#pointer
#const SQL_ATTR_ASYNC_DBC_FUNCTIONS_ENABLE
#const SQL_ASYNC_DBC_ENABLE_ON = uint()
#const SQL_ASYNC_DBC_ENABLE_OFF = uint()
#const SQL_ATTR_ASYNC_DBC_PCALLBACK
#pointer
#const SQL_ATTR_ASYNC_DBC_PCONTEXT
#pointer
const SQL_ATTR_ASYNC_ENABLE = 4
const SQL_ASYNC_ENABLE_OFF = uint(0)
const SQL_ASYNC_ENABLE_ON = uint(1)
const SQL_ATTR_AUTOCOMMIT = 102
const SQL_AUTOCOMMIT_OFF = uint(0)
const SQL_AUTOCOMMIT_ON = uint(1)
const SQL_ATTR_CONNECTION_TIMEOUT = 113
#uint of how long you want the connection timeout
const SQL_ATTR_CURRENT_CATALOG = 109
#string/Ptr{Uint8} of default database to use
#const SQL_ATTR_DBC_INFO_TOKEN
#pointer
const SQL_ATTR_ENLIST_IN_DTC = 1207
#pointer: Pass a DTC OLE transaction object that specifies the transaction to export to
# SQL Server, or SQL_DTC_DONE to end the connection's DTC association.
const SQL_ATTR_LOGIN_TIMEOUT = 103
#uint of how long you want the login timeout
const SQL_ATTR_METADATA_ID = 10014
#SQL_TRUE, SQL_FALSE
const SQL_ATTR_ODBC_CURSORS = 110
const SQL_CUR_USE_IF_NEEDED = uint(0)
const SQL_CUR_USE_ODBC = uint(1)
const SQL_CUR_USE_DRIVER = uint(2)
const SQL_ATTR_PACKET_SIZE = 112
#uint for network packet size
const SQL_ATTR_QUIET_MODE = 111
#window handle pointer
const SQL_ATTR_TRACE = 104
const SQL_OPT_TRACE_OFF = uint(0)
const SQL_OPT_TRACE_ON = uint(1)
const SQL_ATTR_TRACEFILE = 105
#A null-terminated character string containing the name of the trace file.
const SQL_ATTR_TRANSLATE_LIB = 106
# A null-terminated character string containing the name of a library containing the functions SQLDriverToDataSource and
# SQLDataSourceToDriver that the driver accesses to perform tasks such as character set translation.
const SQL_ATTR_TRANSLATE_OPTION = 107
#A 32-bit flag value that is passed to the translation DLL.
const SQL_ATTR_TXN_ISOLATION = 108
#A 32-bit bitmask that sets the transaction isolation level for the current connection.

#Valid value_length
const SQL_IS_POINTER = -4
const SQL_IS_INTEGER = -6
const SQL_IS_UINTEGER = -5
const SQL_NTS = -3

#length of string or binary stream
#Status:
function SQLSetConnectAttr(dbc::Ptr{Void},attribute::Int,value::Union(UTF8String,Uint),value_length::Int)
    @windows_only ret = ccall( (:SQLSetConnectAttr, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int,typeof(value)==UTF8String?Ptr{Uint8}:Ptr{Uint},Int),
        dbc,attribute,value,value_length)
    @unix_only ret = ccall( (:SQLSetConnectAttr, odbc_dm),
            Int16, (Ptr{Void},Int,typeof(value)==UTF8String?Ptr{Uint8}:Ptr{Uint},Int),
            dbc,attribute,value,value_length)
    return ret
end

#SQLGetConnectAttr
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710297(v=vs.85).aspx
#Description: returns the current setting of a connection attribute.
#Valid attributes: see SQLSetConnectAttr in addition to those below
const SQL_ATTR_AUTO_IPD = 10001
#SQL_TRUE, SQL_FALSE
const SQL_ATTR_CONNECTION_DEAD = 1209
const SQL_CD_TRUE = 1
const SQL_CD_FALSE = 0
#Status:
function SQLGetConnectAttr{T,N}(dbc::Ptr{Void},attribute::Int,value::Array{T,N},bytes_returned::Array{Int,1})
    @windows_only ret = ccall( (:SQLGetConnectAttr, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int,Ptr{T},Int,Ptr{Int}),
        dbc,attribute,value,sizeof(T)*N,bytes_returned)
    @unix_only ret = ccall( (:SQLGetConnectAttr, odbc_dm),
            Int16, (Ptr{Void},Int,Ptr{T},Int,Ptr{Int}),
            dbc,attribute,value,sizeof(T)*N,bytes_returned)
    return ret
end

#SQLSetStmtAttr
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms712631(v=vs.85).aspx
#Description: sets attributes related to a statement.
#Valid attributes
const SQL_ATTR_ROW_STATUS_PTR = 25
const SQL_ATTR_ROWS_FETCHED_PTR  = 26
const SQL_ATTR_ROW_ARRAY_SIZE = 27
#this sets the rowset size for ExtendedFetch and FetchScroll
#Valid value_length: See SQLSetConnectAttr; SQL_IS_POINTER, SQL_IS_INTEGER, SQL_IS_UINTEGER, SQL_NTS
#Status:
function SQLSetStmtAttr(stmt::Ptr{Void},attribute::Int,value::Uint,value_length::Int)
    @windows_only ret = ccall( (:SQLSetStmtAttr, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int,Uint,Int),
        stmt,attribute,value,value_length)
    @unix_only ret = ccall( (:SQLSetStmtAttr, odbc_dm),
            Int16, (Ptr{Void},Int,Uint,Int),
            stmt,attribute,value,value_length)
    return ret
end

function SQLSetStmtAttr(stmt::Ptr{Void},attribute::Int,value::Array{Int},value_length::Int)
    @windows_only ret = ccall( (:SQLSetStmtAttr, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int,Ptr{Int},Int),
        stmt,attribute,value,value_length)
    @unix_only ret = ccall( (:SQLSetStmtAttr, odbc_dm),
            Int16, (Ptr{Void},Int,Ptr{Int},Int),
            stmt,attribute,value,value_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715438(v=vs.85).aspx
function SQLGetStmtAttr{T,N}(stmt::Ptr{Void},attribute::Int,value::Array{T,N},bytes_returned::Array{Int,1})
    @windows_only ret = ccall( (:SQLGetStmtAttr, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int,Ptr{T},Int,Ptr{Int}),
        stmt,attribute,value,sizeof(T)*N,bytes_returned)
    @unix_only ret = ccall( (:SQLGetStmtAttr, odbc_dm),
            Int16, (Ptr{Void},Int,Ptr{T},Int,Ptr{Int}),
            stmt,attribute,value,sizeof(T)*N,bytes_returned)
    return ret
end

#SQLFreeStmt
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms709284(v=vs.85).aspx
#Description: stops processing associated with a specific statement,
# closes any open cursors associated with the statement,
# discards pending results, or, optionally,
# frees all resources associated with the statement handle.
#Valid param
const SQL_CLOSE = uint16(0)
const SQL_RESET_PARAMS = uint16(3)
const SQL_UNBIND = uint16(2)

#Status:
function SQLFreeStmt(stmt::Ptr{Void},param::Uint16)
    @windows_only ret = ccall( (:SQLFreeStmt, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16),
        stmt, param)
    @unix_only ret = ccall( (:SQLFreeStmt, odbc_dm),
            Int16, (Ptr{Void},Uint16),
            stmt, param)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713560(v=vs.85).aspx
function SQLSetDescField{T,N}(desc::Ptr{Void},i::Int16,field_id::Int16,value::Array{T,N},value_length::Array{Int,1})
    @windows_only ret = ccall( (:SQLSetDescField, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int16,Int16,Ptr{T},Int),
        desc,field_id,value,value_length)
    @unix_only ret = ccall( (:SQLSetDescField, odbc_dm),
            Int16, (Ptr{Void},Int16,Int16,Ptr{T},Int),
            desc,field_id,value,value_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716370(v=vs.85).aspx
function SQLGetDescField{T,N}(desc::Ptr{Void},i::Int16,attribute::Int16,value::Array{T,N},bytes_returned::Array{Int,1})
    @windows_only ret = ccall( (:SQLGetDescField, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int16,Int16,Ptr{T},Int,Ptr{Int}),
        desc,attribute,value,sizeof(T)*N,bytes_returned)
    @unix_only ret = ccall( (:SQLGetDescField, odbc_dm),
            Int16, (Ptr{Void},Int16,Int16,Ptr{T},Int,Ptr{Int}),
            desc,attribute,value,sizeof(T)*N,bytes_returned)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710921(v=vs.85).aspx
function SQLGetDescRec(desc::Ptr{Void},i::Int16,name::Array{Uint8,1},name_length::Array{Int16,1},type_ptr::Array{Int16,1},subtype_ptr::Array{Int16,1},length_ptr::Array{Int,1},precision_ptr::Array{Int16,1},scale_ptr::Array{Int16,1},nullable_ptr::Array{Int16,1},)
    @windows_only ret = ccall( (:SQLGetDescRec, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int16,Ptr{Uint8},Int16,Ptr{Int16},Ptr{Int16},Ptr{Int16},Ptr{Int},Ptr{Int16},Ptr{Int16},Ptr{Int16}),
        desc,i,name,length(name),name_length,type_ptr,subtype_ptr,length_ptr,precision_ptr,scale_ptr,nullable_ptr)
    @unix_only ret = ccall( (:SQLGetDescRec, odbc_dm),
            Int16, (Ptr{Void},Int16,Ptr{Uint8},Int16,Ptr{Int16},Ptr{Int16},Ptr{Int16},Ptr{Int},Ptr{Int16},Ptr{Int16},Ptr{Int16}),
            desc,i,name,length(name),name_length,type_ptr,subtype_ptr,length_ptr,precision_ptr,scale_ptr,nullable_ptr)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715378(v=vs.85).aspx
function SQLCopyDesc(source_desc::Ptr{Void},dest_desc::Ptr{Void})
    @windows_only ret = ccall( (:SQLCopyDesc, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Void}),
        source_desc,dest_desc)
    @unix_only ret = ccall( (:SQLCopyDesc, odbc_dm),
            Int16, (Ptr{Void},Ptr{Void}),
            source_desc,dest_desc)
    return ret
end

### Connection Functions ###
# SQLConnect
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms711810(v=vs.85).aspx
# Description: establishes connections to a driver and a data source
# Status:
function SQLConnect(dbc::Ptr{Void},dsn::UTF8String,username::UTF8String,password::UTF8String)
    @windows_only ret = ccall( (:SQLConnect, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
        dbc,dsn,sizeof(dsn),username,sizeof(username),password,sizeof(password))
    @unix_only ret = ccall( (:SQLConnect, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
            dbc,dsn,sizeof(dsn),username,sizeof(username),password,sizeof(password))
    return ret
end

#SQLDriverConnect
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715433(v=vs.85).aspx
#Description:
#Valid driver_prompt
const SQL_DRIVER_COMPLETE = uint16(1)
const SQL_DRIVER_COMPLETE_REQUIRED = uint16(3)
const SQL_DRIVER_NOPROMPT = uint16(0)
const SQL_DRIVER_PROMPT = uint16(2)
#Status:
function SQLDriverConnect(dbc::Ptr{Void},window_handle::Ptr{Void},conn_string::UTF8String,out_conn::Ptr{Void},out_buff::Array{Int16,1},driver_prompt::Uint16)
    @windows_only ret = ccall( (:SQLDriverConnect, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Void},Ptr{Uint8},Int16,Ptr{Void},Int16,Ptr{Int16},Uint16),
        dbc,window_handle,conn_string,sizeof(conn_string),out_conn,0,out_buff,driver_prompt)
    @unix_only ret = ccall( (:SQLDriverConnect, odbc_dm),
            Int16, (Ptr{Void},Ptr{Void},Ptr{Uint8},Int16,Ptr{Void},Int16,Ptr{Int16},Uint16),
            dbc,window_handle,conn_string,sizeof(conn_string),out_conn,0,out_buff,driver_prompt)
    return ret
end
#SQLBrowseConnect
 #http://msdn.microsoft.com/en-us/library/windows/desktop/ms714565(v=vs.85).aspx
 #Description: supports an iterative method of discovering and enumerating the attributes and attribute values required to connect to a data source
 #Status:
function SQLBrowseConnect(dbc::Ptr{Void},instring::UTF8String,outstring::Array{Uint8,1},indicator::Array{Int16,1})
    @windows_only ret = ccall( (:SQLBrowseConnect, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Int16}),
        dbc,instring,sizeof(instring),outstring,sizeof(outstring),indicator)
    @unix_only ret = ccall( (:SQLBrowseConnect, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Int16}),
            dbc,instring,sizeof(instring),outstring,sizeof(outstring),indicator)
    return ret
end
#SQLDisconnect
 #http://msdn.microsoft.com/en-us/library/windows/desktop/ms713946(v=vs.85).aspx
 #Description: closes the connection associated with a specific connection handle
 #Status:
function SQLDisconnect(dbc::Ptr{Void})
    @windows_only ret = ccall( (:SQLDisconnect, odbc_dm), stdcall,
        Int16, (Ptr{Void},),
        dbc)
    @unix_only ret = ccall( (:SQLDisconnect, odbc_dm),
            Int16, (Ptr{Void},),
            dbc)
    return ret
end
#SQLGetFunctions
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms709291(v=vs.85).aspx
#Descriptions:
#Valid functionid

#supported will be SQL_TRUE or SQL_FALSE
#Status:
function SQLGetFunctions(dbc::Ptr{Void},functionid::Uint16,supported::Array{Uint16,1})
    @windows_only ret = ccall( (:SQLGetFunctions, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16,Ptr{Uint16}),
        dbc,functionid,supported)
    @unix_only ret = ccall( (:SQLGetFunctions, odbc_dm),
            Int16, (Ptr{Void},Uint16,Ptr{Uint16}),
            dbc,functionid,supported)
    return ret
end

#SQLGetInfo
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711681(v=vs.85).aspx
#Description:
#Status:
function SQLGetInfo{T,N}(dbc::Ptr{Void},attribute::Int,value::Array{T,N},bytes_returned::Array{Int,1})
    @windows_only ret = ccall( (:SQLGetInfo, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int,Ptr{T},Int,Ptr{Int}),
        dbc,attribute,value,sizeof(T)*N,bytes_returned)
    @unix_only ret = ccall( (:SQLGetInfo, odbc_dm),
            Int16, (Ptr{Void},Int,Ptr{T},Int,Ptr{Int}),
            dbc,attribute,value,sizeof(T)*N,bytes_returned)
    return ret
end

#### Query Functions ####
#SQLNativeSql
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714575(v=vs.85).aspx
#Description: returns the SQL string as modified by the driver
#Status:
function SQLNativeSql(dbc::Ptr{Void},query_string::UTF8String,output_string::Array{Uint8,1},length_ind::Array{Int,1})
    @windows_only ret = ccall( (:SQLNativeSql, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int,Ptr{Uint8},Int,Ptr{Int}),
        dbc,query_string,sizeof(query_string),output_string,sizeof(output_string),length_ind)
    @unix_only ret = ccall( (:SQLNativeSql, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int,Ptr{Uint8},Int,Ptr{Int}),
            dbc,query_string,sizeof(query_string),output_string,sizeof(output_string),length_ind)
    return ret
end

#SQLGetTypeInfo
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714632(v=vs.85).aspx
#Description:
#valid sqltype
#const SQL_ALL_TYPES =
#Status:
function SQLGetTypeInfo(stmt::Ptr{Void},sqltype::Int16)
    @windows_only ret = ccall( (:SQLGetTypeInfo, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int16),
        stmt,sqltype)
    @unix_only ret = ccall( (:SQLGetTypeInfo, odbc_dm),
            Int16, (Ptr{Void},Int16),
            stmt,sqltype)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713824(v=vs.85).aspx
function SQLPutData{T}(stmt::Ptr{Void},data::Array{T},data_length::Int)
    @windows_only ret = ccall( (:SQLPutData, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{T},Int),
        stmt,data,data_length)
    @unix_only ret = ccall( (:SQLPutData, odbc_dm),
            Int16, (Ptr{Void},Ptr{T},Int),
            stmt,data,data_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710926(v=vs.85).aspx
function SQLPrepare(stmt::Ptr{Void},query_string::UTF8String)
    @windows_only ret = ccall( (:SQLPrepare, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16),
        stmt,query_string,sizeof(query_string))
    @unix_only ret = ccall( (:SQLPrepare, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16),
            stmt,query_string,sizeof(query_string))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713584(v=vs.85).aspx
function SQLExecute(stmt::Ptr{Void})
    @windows_only ret = ccall( (:SQLExecute, odbc_dm), stdcall,
        Int16, (Ptr{Void},),
        stmt)
    @unix_only ret = ccall( (:SQLExecute, odbc_dm),
            Int16, (Ptr{Void},),
            stmt)
    return ret
end

#SQLExecDirect
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713611(v=vs.85).aspx
#Description: executes a preparable statement
#Status:
function SQLExecDirect(stmt::Ptr{Void},query::UTF8String)
    @windows_only ret = ccall( (:SQLExecDirect, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int),
        stmt,query,sizeof(query))
    @unix_only ret = ccall( (:SQLExecDirect, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int),
            stmt,query,sizeof(query))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714112(v=vs.85).aspx
function SQLCancel(stmt::Ptr{Void})
    @windows_only ret = ccall( (:SQLCancel, odbc_dm), stdcall,
        Int16, (Ptr{Void},),
        stmt)
    @unix_only ret = ccall( (:SQLCancel, odbc_dm),
            Int16, (Ptr{Void},),
            stmt)
    return ret
end

#### Resultset Metadata Functions ####
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715393(v=vs.85).aspx
function SQLNumResultCols(stmt::Ptr{Void},cols::Array{Int16,1})
    @windows_only ret = ccall( (:SQLNumResultCols, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Int16}),
        stmt, cols)
    @unix_only ret = ccall( (:SQLNumResultCols, odbc_dm),
            Int16, (Ptr{Void},Ptr{Int16}),
            stmt, cols)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711835(v=vs.85).aspx
function SQLRowCount(stmt::Ptr{Void},rows::Array{Int,1})
    @windows_only ret = ccall( (:SQLRowCount, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Int}),
        stmt, rows)
    @unix_only ret = ccall( (:SQLRowCount, odbc_dm),
            Int16, (Ptr{Void},Ptr{Int}),
            stmt, rows)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713558(v=vs.85).aspx
function SQLColAttribute(stmt::Ptr{Void},x::Int,)
    @windows_only ret = ccall( (:SQLColAttribute, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16,Uint16,Ptr,Int16,Ptr{Int16},Ptr{Int}),
        stmt,x,)
    @unix_only ret = ccall( (:SQLColAttribute, odbc_dm),
            Int16, (Ptr{Void},Uint16,Uint16,Ptr,Int16,Ptr{Int16},Ptr{Int}),
            stmt,x,)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716289(v=vs.85).aspx
function SQLDescribeCol(stmt::Ptr{Void},x::Int,column_name::Array{Uint8,1},name_length::Array{Int16,1},datatype::Array{Int16,1},column_size::Array{Int,1},decimal_digits::Array{Int16,1},nullable::Array{Int16,1})
    @windows_only ret = ccall( (:SQLDescribeCol, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16,Ptr{Uint8},Int16,Ptr{Int16},Ptr{Int16},Ptr{Int},Ptr{Int16},Ptr{Int16}),
        stmt,x,column_name,length(column_name),name_length,datatype,column_size,decimal_digits,nullable)
    @unix_only ret = ccall( (:SQLDescribeCol, odbc_dm),
            Int16, (Ptr{Void},Uint16,Ptr{Uint8},Int16,Ptr{Int16},Ptr{Int16},Ptr{Int},Ptr{Int16},Ptr{Int16}),
            stmt,x,column_name,length(column_name),name_length,datatype,column_size,decimal_digits,nullable)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710188(v=vs.85).aspx
function SQLDescribeParam(stmt::Ptr{Void},x::Int,sqltype::Array{Int16,1},column_size::Array{Int,1},decimal_digits::Array{Int16,1},nullable::Array{Int16,1})
    @windows_only ret = ccall( (:SQLDescribeParam, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16,Ptr{Int16},Ptr{Int},Ptr{Int16},Ptr{Int16}),
        stmt,x,sqltype,column_size,decimal_digits,nullable)
    @unix_only ret = ccall( (:SQLDescribeParam, odbc_dm),
            Int16, (Ptr{Void},Uint16,Ptr{Int16},Ptr{Int},Ptr{Int16},Ptr{Int16}),
            stmt,x,sqltype,column_size,decimal_digits,nullable)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms712366(v=vs.85).aspx
function SQLParamData(stmt::Ptr{Void},ptr_buffer::Array{Ptr{Void},1})
    @windows_only ret = ccall( (:SQLParamData, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Void}),
        stmt,ptr_buffer)
    @unix_only ret = ccall( (:SQLParamData, odbc_dm),
            Int16, (Ptr{Void},Ptr{Void}),
            stmt,ptr_buffer)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715409(v=vs.85).aspx
function SQLNumParams(stmt::Ptr{Void},param_count::Array{Int16,1})
    @windows_only ret = ccall( (:SQLNumParams, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Int16}),
        stmt,param_count)
    @unix_only ret = ccall( (:SQLNumParams, odbc_dm),
            Int16, (Ptr{Void},Ptr{Int16}),
            stmt,param_count)
    return ret
end

#### Resultset Retrieval Functions ####
#SQLBindParameter
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710963(v=vs.85).aspx
#Description:
#valid iotype
const SQL_PARAM_INPUT = int16(1)
const SQL_PARAM_OUTPUT = int16(4)
const SQL_PARAM_INPUT_OUTPUT = int16(2)
#const SQL_PARAM_INPUT_OUTPUT_STREAM = int16()
#const SQL_PARAM_OUTPUT_STREAM = int16()
#Status:
function SQLBindParameter{T}(stmt::Ptr{Void},x::Int,iotype::Int16,ctype::Int16,sqltype::Int16,column_size::Int,decimal_digits::Int,param_value::Array{T},param_size::Int)
    @windows_only ret = ccall( (:SQLBindParameter, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16,Int16,Int16,Int16,Uint,Int16,Ptr{T},Int,Ptr{Void}),
        stmt,x,iotype,ctype,sqltype,column_size,decimal_digits,param_value,param_size,C_NULL)
    @unix_only ret = ccall( (:SQLBindParameter, odbc_dm),
            Int16, (Ptr{Void},Uint16,Int16,Int16,Int16,Uint,Int16,Ptr{T},Int,Ptr{Void}),
            stmt,x,iotype,ctype,sqltype,column_size,decimal_digits,param_value,param_size,C_NULL)
    return ret
end
SQLSetParam = SQLBindParameter

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711010(v=vs.85).aspx
function SQLBindCols{T,N}(stmt::Ptr{Void},x::Int,ctype::Int16,holder::Array{T,N},jlsize::Int,indicator::Array{Int,1})
    @windows_only ret = ccall( (:SQLBindCol, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16,Int16,Ptr{T},Int,Ptr{Int}),
        stmt,x,ctype,holder,jlsize,indicator)
    @unix_only ret = ccall( (:SQLBindCol, odbc_dm),
            Int16, (Ptr{Void},Uint16,Int16,Ptr{T},Int,Ptr{Int}),
            stmt,x,ctype,holder,jlsize,indicator)
    return ret
end

function SQLBindCols(stmt::Ptr{Void},x::Int,ctype::Int16,holder::Array{UTF8String,1},jlsize::Int,indicator::Array{Int,1})
    @windows_only ret = ccall( (:SQLBindCol, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16,Int16,Ptr{Uint8},Int,Ptr{Int}),
        stmt,x,ctype,holder,jlsize,indicator)
    @unix_only ret = ccall( (:SQLBindCol, odbc_dm),
            Int16, (Ptr{Void},Uint16,Int16,Ptr{Uint8},Int,Ptr{Int}),
            stmt,x,ctype,holder,jlsize,indicator)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711707(v=vs.85).aspx
function SQLSetCursorName(stmt::Ptr{Void},cursor::UTF8String)
    @windows_only ret = ccall( (:SQLSetCursorName, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16),
        stmt,cursor,sizeof(cursor))
    @unix_only ret = ccall( (:SQLSetCursorName, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16),
            stmt,cursor,sizeof(cursor))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716209(v=vs.85).aspx
function SQLGetCursorName(stmt::Ptr{Void},cursor::Array{Uint8,1},cursor_length::Array{Int16,1})
    @windows_only ret = ccall( (:SQLGetCursorName, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Int16}),
        stmt,cursor,length(cursor),cursor_length)
    @unix_only ret = ccall( (:SQLGetCursorName, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Int16}),
            stmt,cursor,length(cursor),cursor_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715441(v=vs.85).aspx
function SQLGetData{T,N}(stmt::Ptr{Void},i::Int,ctype::Int16,value::Array{T,N},bytes_returned::Array{Int,1})
    @windows_only ret = ccall( (:SQLGetData, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16,Int16,Ptr{T},Int,Ptr{Int}),
        stmt,i,ctype,value,sizeof(T)*N,bytes_returned)
    @unix_only ret = ccall( (:SQLGetData, odbc_dm),
            Int16, (Ptr{Void},Uint16,Int16,Ptr{T},Int,Ptr{Int}),
            stmt,i,ctype,value,sizeof(T)*N,bytes_returned)
    return ret
end

#SQLFetchScroll
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714682(v=vs.85).aspx
#Description:
#valid fetch_orientation
const SQL_FETCH_NEXT = int16(1)
const SQL_FETCH_PRIOR = int16(4)
const SQL_FETCH_FIRST = int16(2)
const SQL_FETCH_LAST = int16(3)
const SQL_FETCH_ABSOLUTE = int16(5)
const SQL_FETCH_RELATIVE = int16(6)
const SQL_FETCH_BOOKMARK = int16(8)
#Status:
function SQLFetchScroll(stmt::Ptr{Void},fetch_orientation::Int16,fetch_offset::Int)
    @windows_only ret = ccall( (:SQLFetchScroll, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int16,Int),
        stmt,fetch_orientation,fetch_offset)
    @unix_only ret = ccall( (:SQLFetchScroll, odbc_dm),
            Int16, (Ptr{Void},Int16,Int),
            stmt,fetch_orientation,fetch_offset)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713591(v=vs.85).aspx
function SQLExtendedFetch(stmt::Ptr{Void},fetch_orientation::Uint16,fetch_offset::Int,row_count_ptr::Array{Int,1},row_status_array::Array{Int16,1})
    @windows_only ret = ccall( (:SQLExtendedFetch, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16,Int,Ptr{Int},Ptr{Int16}),
        stmt,fetch_orientation,fetch_offset,row_count_ptr,row_status_array)
    @unix_only ret = ccall( (:SQLExtendedFetch, odbc_dm),
            Int16, (Ptr{Void},Uint16,Int,Ptr{Int},Ptr{Int16}),
            stmt,fetch_orientation,fetch_offset,row_count_ptr,row_status_array)
    return ret
end

#SQLSetPos
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713507(v=vs.85).aspx
#Description:
#valid operation
const SQL_POSITION = uint16(0) #SQLSetPos
const SQL_REFRESH = uint16(1) #SQLSetPos
const SQL_UPDATE = uint16(2) #SQLSetPos
const SQL_DELETE = uint16(3) #SQLSetPos
#valid lock_type
const SQL_LOCK_NO_CHANGE = uint16(0) #SQLSetPos
const SQL_LOCK_EXCLUSIVE = uint16(1) #SQLSetPos
const SQL_LOCK_UNLOCK = uint16(2) #SQLSetPos
#Status
function SQLSetPos{T}(stmt::Ptr{Void},rownumber::T,operation::Uint16,lock_type::Uint16)
    @windows_only ret = ccall( (:SQLSetPos, odbc_dm), stdcall,
        Int16, (Ptr{Void},T,Uint16,Uint16),
        stmt,rownumber,operation,lock_type)
    @unix_only ret = ccall( (:SQLSetPos, odbc_dm),
            Int16, (Ptr{Void},T,Uint16,Uint16),
            stmt,rownumber,operation,lock_type)
    return ret
end #T can be Uint64 or Uint16 it seems

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714673(v=vs.85).aspx
function SQLMoreResults(stmt::Ptr{Void})
    @windows_only ret = ccall( (:SQLMoreResults, odbc_dm), stdcall,
        Int16, (Ptr{Void},),
        stmt)
    @unix_only ret = ccall( (:SQLMoreResults, odbc_dm),
            Int16, (Ptr{Void},),
            stmt)
    return ret
end

#SQLEndTran
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716544(v=vs.85).aspx
#Description:
#valid completion_type
const SQL_COMMIT = int16(0) #SQLEndTran
const SQL_ROLLBACK = int16(1) #SQLEndTran
#Status:
function SQLEndTran(handletype::Int16,handle::Ptr{Void},completion_type::Int16)
    @windows_only ret = ccall( (:SQLEndTran, odbc_dm), stdcall,
        Int16, (Int16,Ptr{Void},Int16),
        handletype,handle,completion_type)
    @unix_only ret = ccall( (:SQLEndTran, odbc_dm),
            Int16, (Int16,Ptr{Void},Int16),
            handletype,handle,completion_type)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms709301(v=vs.85).aspx
function SQLCloseCursor(stmt::Ptr{Void})
    @windows_only ret = ccall( (:SQLCloseCursor, odbc_dm), stdcall,
        Int16, (Ptr{Void},),
        stmt)
    @unix_only ret = ccall( (:SQLCloseCursor, odbc_dm),
            Int16, (Ptr{Void},),
            stmt)
    return ret
end

#SQLBulkOperations
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms712471(v=vs.85).aspx
#Description:
#valid operation
const SQL_ADD = uint16(4) #SQLBulkOperations
const SQL_UPDATE_BY_BOOKMARK = uint16(5) #SQLBulkOperations
const SQL_DELETE_BY_BOOKMARK = uint16(6) #SQLBulkOperations
const SQL_FETCH_BY_BOOKMARK = uint16(7) #SQLBulkOperations
#Status:
function SQLBulkOperations(stmt::Ptr{Void},operation::Uint16)
    @windows_only ret = ccall( (:SQLBulkOperations, odbc_dm), stdcall,
        Int16, (Ptr{Void},Uint16),
        stmt,operation)
    @unix_only ret = ccall( (:SQLBulkOperations, odbc_dm),
            Int16, (Ptr{Void},Uint16),
            stmt,operation)
    return ret
end

#### DBMS Meta Functions ####
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711683(v=vs.85).aspx
function SQLColumns(stmt::Ptr{Void},catalog::UTF8String,schema::UTF8String,table::UTF8String,column::UTF8String)
    @windows_only ret = ccall( (:SQLColumnPrivileges, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
        stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),column,sizeof(column))
    @unix_only ret = ccall( (:SQLColumnPrivileges, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
            stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),column,sizeof(column))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716336(v=vs.85).aspx
function SQLColumnPrivileges(stmt::Ptr{Void},catalog::UTF8String,schema::UTF8String,table::UTF8String,column::UTF8String)
    @windows_only ret = ccall( (:SQLColumnPrivileges, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
        stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),column,sizeof(column))
    @unix_only ret = ccall( (:SQLColumnPrivileges, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
            stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),column,sizeof(column))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms709315(v=vs.85).aspx
function SQLForeignKeys(stmt::Ptr{Void},pkcatalog::UTF8String,pkschema::UTF8String,pktable::UTF8String,fkcatalog::UTF8String,fkschema::UTF8String,fktable::UTF8String)
    @windows_only ret = ccall( (:SQLForeignKeys, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
        stmt,pkcatalog,sizeof(pkcatalog),pkschema,sizeof(pkschema),pktable,sizeof(pktable),fkcatalog,sizeof(fkcatalog),fkschema,sizeof(fkschema),fktable,sizeof(fktable))
    @unix_only ret = ccall( (:SQLForeignKeys, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
            stmt,pkcatalog,sizeof(pkcatalog),pkschema,sizeof(pkschema),pktable,sizeof(pktable),fkcatalog,sizeof(fkcatalog),fkschema,sizeof(fkschema),fktable,sizeof(fktable))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711005(v=vs.85).aspx
function SQLPrimaryKeys(stmt::Ptr{Void},catalog::UTF8String,schema::UTF8String,table::UTF8String)
    @windows_only ret = ccall( (:SQLPrimaryKeys, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
        stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table))
    @unix_only ret = ccall( (:SQLPrimaryKeys, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
            stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711701(v=vs.85).aspx
function SQLProcedureColumns(stmt::Ptr{Void},catalog::UTF8String,schema::UTF8String,proc::UTF8String,column::UTF8String)
    @windows_only ret = ccall( (:SQLProcedureColumns, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
        stmt,catalog,sizeof(catalog),schema,sizeof(schema),proc,sizeof(proc),column,sizeof(column))
    @unix_only ret = ccall( (:SQLProcedureColumns, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
            stmt,catalog,sizeof(catalog),schema,sizeof(schema),proc,sizeof(proc),column,sizeof(column))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715368(v=vs.85).aspx
function SQLProcedures(stmt::Ptr{Void},catalog::UTF8String,schema::UTF8String,proc::UTF8String)
    @windows_only ret = ccall( (:SQLProcedures, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
        stmt,catalog,sizeof(catalog),schema,sizeof(schema),proc,sizeof(proc))
    @unix_only ret = ccall( (:SQLProcedures, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
            stmt,catalog,sizeof(catalog),schema,sizeof(schema),proc,sizeof(proc))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711831(v=vs.85).aspx
function SQLTables(stmt::Ptr{Void},catalog::UTF8String,schema::UTF8String,table::UTF8String,table_type::UTF8String)
    @windows_only ret = ccall( (:SQLTables, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
        stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),table_type,sizeof(table_type))
    @unix_only ret = ccall( (:SQLTables, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
            stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),table_type,sizeof(table_type))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713565(v=vs.85).aspx
function SQLTablePrivileges(stmt::Ptr{Void},catalog::UTF8String,schema::UTF8String,table::UTF8String)
    @windows_only ret = ccall( (:SQLTablePrivileges, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
        stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table))
    @unix_only ret = ccall( (:SQLTablePrivileges, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16),
            stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table))
    return ret
end

#SQLStatistics
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711022(v=vs.85).aspx
#Description:
#valid unique
const SQL_INDEX_ALL = uint16(1)
const SQL_INDEX_CLUSTERED = uint16(1)
const SQL_INDEX_HASHED = uint16(2)
const SQL_INDEX_OTHER = uint16(3)
const SQL_INDEX_UNIQUE = uint16(0)
#valid reserved
const SQL_ENSURE = uint16(1)
const SQL_QUICK = uint16(0)
#Status:
function SQLStatistics(stmt::Ptr{Void},catalog::UTF8String,schema::UTF8String,table::UTF8String,unique::Uint16,reserved::Uint16)
    @windows_only ret = ccall( (:SQLStatistics, odbc_dm), stdcall,
        Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Uint16,Uint16),
        stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),unique,reserved)
    @unix_only ret = ccall( (:SQLStatistics, odbc_dm),
            Int16, (Ptr{Void},Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Uint16,Uint16),
            stmt,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),unique,reserved)
    return ret
end

#SQLSpecialColumns
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714602(v=vs.85).aspx
#Description:
#valid id_type
const SQL_BEST_ROWID = int16(1) #SQLSpecialColumns
const SQL_ROWVER = int16(2) #SQLSpecialColumns
#valid scope
const SQL_SCOPE_CURROW = int16(0) #SQLSpecialColumns
const SQL_SCOPE_SESSION = int16(2) #SQLSpecialColumns
const SQL_SCOPE_TRANSACTION = int16(1) #SQLSpecialColumns
#valid nullable
const SQL_NO_NULLS = int16(0) #SQLSpecialColumns
const SQL_NULLABLE = int16(1) #SQLSpecialColumns
#const SQL_NULLABLE_UNKNOWN = int16() #SQLSpecialColumns
#Status:
function SQLSpecialColumns(stmt::Ptr{Void},id_type::Int16,catalog::UTF8String,schema::UTF8String,table::UTF8String,scope::Int16,nullable::Int16)
    @windows_only ret = ccall( (:SQLSpecialColumns, odbc_dm), stdcall,
        Int16, (Ptr{Void},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Int16,Int16),
        stmt,id_type,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),scope,nullable)
    @unix_only ret = ccall( (:SQLSpecialColumns, odbc_dm),
            Int16, (Ptr{Void},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Ptr{Uint8},Int16,Int16,Int16),
            stmt,id_type,catalog,sizeof(catalog),schema,sizeof(schema),table,sizeof(table),scope,nullable)
    return ret
end

#### Error Handling Functions ####
#TODO: add consts
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710181(v=vs.85).aspx
function SQLGetDiagField(handletype::Int16,handle::Ptr{Void},i::Int16,diag_id::Int16,diag_info::Array{Uint,1},buffer_length::Int16,diag_length::Array{Int16,1})
    @windows_only ret = ccall( (:SQLGetDiagField, odbc_dm), stdcall,
        Int16, (Int16,Ptr{Void},Int16,Int16,Ptr{Uint8},Int16,Ptr{Int16}),
        handletype,handle,i,diag_id,diag_info,buffer_length,msg_length)
    @unix_only ret = ccall( (:SQLGetDiagField, odbc_dm),
            Int16, (Int16,Ptr{Void},Int16,Int16,Ptr{Uint8},Int16,Ptr{Int16}),
            handletype,handle,i,diag_id,diag_info,buffer_length,msg_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716256(v=vs.85).aspx
function SQLGetDiagRec(handletype::Int16,handle::Ptr{Void},i::Int16,state::Array{Uint8,1},native::Array{Int,1},error_msg::Array{Uint8,1},msg_length::Array{Int16,1})
    @windows_only ret = ccall( (:SQLGetDiagRec, odbc_dm), stdcall,
        Int16, (Int16,Ptr{Void},Int16,Ptr{Uint8},Ptr{Int},Ptr{Uint8},Int16,Ptr{Int16}),
        handletype,handle,i,state,native,error_msg,length(error_msg),msg_length)
    @unix_only ret = ccall( (:SQLGetDiagRec, odbc_dm),
            Int16, (Int16,Ptr{Void},Int16,Ptr{Uint8},Ptr{Int},Ptr{Uint8},Int16,Ptr{Int16}),
            handletype,handle,i,state,native,error_msg,length(error_msg),msg_length)
    return ret
end
