%%%-------------------------------------------------------------------
%%% @author jrj
%%% @copyright (C) 2016, <COMPANY>
%%% @doc Provide string datetime manipulation functions
%%%
%%% @end
%%% Created : 26. Feb 2017 01:49 PM
%%%-------------------------------------------------------------------
-module(timestamp_x).
-include_lib("eunit/include/eunit.hrl").
-author("jrj").

%% API exports
-export([
  now/1
  ,now/0
  ,new/1
  ,convert/2            %%内部类型转换
  ,to_datetime/2
]).

-define(SEC_PER_DAY, 86400).
-define(SEC_PER_HOUR, 3600).
-define(SEC_PER_MIN, 60).


%%%===================================================================
%%% Types
%%%===================================================================
-type byte4() :: <<_:32>>.
-type byte6() :: <<_:48>>.
-type byte8() :: <<_:64>>.
-type byte20() :: <<_:160>>.
-type byte27() :: <<_:216>>.
-type year() :: integer().
-type month() :: 1..12.
-type day() :: 1..31.
-type hour() :: 0..24.
-type minute() :: 1..60.
-type second() :: 1..60.
-type microSec() :: integer().


-type ts_binary() :: {ts_binary,byte20()}.
-type ts_datetime() :: {ts_datetime,{{year(),month(),day()},{hour(),minute(),second()},microSec()}}.
-type ts_tz() :: {ts_tz,string()}.
-type ts_tz_ali() :: {ts_tz_ali,byte27()}.
-type ts_unix() :: {ts_unix,integer()}.
-type ts_epoch() :: {ts_epoch,integer()}.

-type date_yyyymmdd() :: {date_yyyymmdd,byte8()}.
-type date_mmdd() :: {date_mmdd,byte4()}.
-type date_internal() :: {date_internal,{integer(),integer(),integer()}}.
-type time_hhmmss() :: {time_hhmmss,byte6()}.
-type time_internal() :: {time_internal,{hour(),minute(),second()}}.

-type dt_type() :: date_yyyymmdd | date_mmdd | date_internal | time_hhmmss | time_internal.
-type datetime_type() :: date_yyyymmdd() | date_mmdd() | date_internal() | time_hhmmss() | time_internal().
-type ts_type() :: ts_binary | ts_datetime | ts_tz | ts_tz_ali | ts_unix | ts_epoch .
-type ts_timestamp() :: ts_binary() | ts_datetime() | ts_tz() | ts_tz_ali() |  ts_unix() |  ts_epoch().

%%====================================================================
%% API functions
%%====================================================================
%% <<"2017-03-28T09:28:19.822000+08:00">>
now() ->
  now(local).
%%<<"2017-03-28T09:28:39.384000+08:00">>
now(local) ->
  list_to_binary(now_to_local_string(erlang:timestamp()));
%% {ts_binary,<<"20170328092855603000">>}
now(ts_binary) ->
  {ts_binary,list_to_binary(now_to_ts_binary(erlang:timestamp()))};
%% {ts_datetime,{{2017,3,28},{9,29,8},197000}}
now(ts_datetime) ->
  {ts_datetime,now_to_ts_datetime(erlang:timestamp())};
%%iso时间 {ts_tz,<<"20170328T09:29:23">>}
now(ts_tz) ->
  {ts_tz,list_to_binary(timestamp_to_iso(calendar:local_time()))};
%%utc时间 {ts_tz_ali,<<"2017-03-28T09:30:03.978000Z">>}
now(ts_tz_ali) ->
  {ts_tz_ali,list_to_binary(now_to_utc_string(erlang:timestamp()))};
%% {ts_unix,1490664655}
now(ts_unix) ->
  {ts_unix,erlang:system_time(seconds)};
now(ts_epoch) ->
  {ts_epoch,erlang:system_time(seconds)}.

now_to_local_string({MegaSecs, Secs, MicroSecs}) ->
  LocalTime = calendar:now_to_local_time({MegaSecs, Secs, MicroSecs}),
  UTCTime = calendar:now_to_universal_time({MegaSecs, Secs, MicroSecs}),
  Seconds = calendar:datetime_to_gregorian_seconds(LocalTime) -
    calendar:datetime_to_gregorian_seconds(UTCTime),
  {{H, M, _}, Sign} = if
                        Seconds < 0 ->
                          {calendar:seconds_to_time(-Seconds), "-"};
                        true ->
                          {calendar:seconds_to_time(Seconds), "+"}
                      end,
  {{Year, Month, Day}, {Hour, Minute, Second}} = LocalTime,
  lists:flatten(
    io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0w.~6..0w~s~2..0w:~2..0w",
      [Year, Month, Day, Hour, Minute, Second, MicroSecs, Sign, H, M])).
now_to_utc_string({MegaSecs, Secs, MicroSecs}) ->
  {{Year, Month, Day}, {Hour, Minute, Second}} =
    calendar:now_to_local_time({MegaSecs, Secs, MicroSecs}),
  lists:flatten(
    io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0w.~6..0wZ",
      [Year, Month, Day, Hour, Minute, Second, MicroSecs])).
now_to_ts_binary({MegaSecs, Secs, MicroSecs}) ->
  {{Year, Month, Day}, {Hour, Minute, Second}} =
    calendar:now_to_local_time({MegaSecs, Secs, MicroSecs}),
  lists:flatten(
    io_lib:format("~4..0w~2..0w~2..0w~2..0w~2..0w~2..0w~6..0w",
      [Year, Month, Day, Hour, Minute, Second, MicroSecs])).
now_to_ts_datetime({MegaSecs, Secs, MicroSecs}) ->
  {{Year, Month, Day}, {Hour, Minute, Second}} =
    calendar:now_to_local_time({MegaSecs, Secs, MicroSecs}),
  {{Year, Month, Day}, {Hour, Minute, Second}, MicroSecs}.
timestamp_to_iso({{Year, Month, Day}, {Hour, Minute, Second}}) ->
  lists:flatten(
    io_lib:format("~4..0w~2..0w~2..0wT~2..0w:~2..0w:~2..0w",
      [Year, Month, Day, Hour, Minute, Second])).

-spec new(Timestamp) -> ts_timestamp() when
  Timestamp :: byte20()| {{year(),month(),day()},{hour(),minute(),second()},microSec()}|
                string() |byte27()|integer().

new(Timestamp) when byte_size(Timestamp) =:= 20 ->
  {ts_binary,Timestamp};
new(Timestamp) when byte_size(Timestamp) =:= 27 ->
  {ts_tz_ali,Timestamp};
new({{Year,Month,Day},{Hour,Minute,Second},MicroSec}) ->
  {ts_datetime,{{Year,Month,Day},{Hour,Minute,Second},MicroSec}};
new(Unix) when is_integer(Unix)->
  {ts_unix,Unix};
new(Iso) ->
  {ts_tz,Iso}.

%%<<"20170328092855603000">> to {{2017,3,28},{9,29,8},197000}
to_ts_datetime({ts_binary,<<Year:4/bytes,Month:2/bytes,Day:2/bytes
                            ,Hour:2/bytes,Minute:2/bytes,Second:2/bytes,MicroSec:6/bytes>>})->
  {ts_datetime,{{binary_to_integer(Year),binary_to_integer(Month),binary_to_integer(Day)},
    {binary_to_integer(Hour),binary_to_integer(Minute),binary_to_integer(Second)},binary_to_integer(MicroSec)}};
%% <<"20170328T09:29:23">> to {{2017,3,28},{9,29,8},197000}
to_ts_datetime({ts_datetime,Datetime})->
  {ts_datetime,Datetime};
to_ts_datetime({ts_tz,<<Year:4/bytes,Month:2/bytes,Day:2/bytes, _T:1/bytes,
  Hour:2/bytes,_M:1/bytes,Minute:2/bytes,_M:1/bytes,Second:2/bytes>>})->
  {ts_datetime,{{binary_to_integer(Year),binary_to_integer(Month),binary_to_integer(Day)},
    {binary_to_integer(Hour),binary_to_integer(Minute),binary_to_integer(Second)},binary_to_integer(<<"000000">>)}};
%% {ts_tz_ali,<<"2017-03-28T09:30:03.978000Z">>} to {{2017,3,28},{9,29,8},197000}
to_ts_datetime({ts_tz_ali,<<Year:4/bytes,_G:1/bytes,Month:2/bytes,_G:1/bytes,Day:2/bytes, _T:1/bytes,
  Hour:2/bytes,_M:1/bytes,Minute:2/bytes,_M:1/bytes,Second:2/bytes,_P:1/bytes,MicroSec:6/bytes,_Z:1/bytes>>})->
  {ts_datetime,{{binary_to_integer(Year),binary_to_integer(Month),binary_to_integer(Day)},
    {binary_to_integer(Hour),binary_to_integer(Minute),binary_to_integer(Second)},binary_to_integer(MicroSec)}};
%% {ts_unix,1490664688} to {{2017,3,28},{9,29,8},197000}
to_ts_datetime({ts_unix,Timer})->
  {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:universal_time_to_local_time(calendar:gregorian_seconds_to_datetime(Timer+719528*24*3600)),
  {ts_datetime,{{Year, Month, Day},{Hour, Minute, Second},000000}};
to_ts_datetime({ts_epoch,Timer})->
  {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:universal_time_to_local_time(calendar:gregorian_seconds_to_datetime(Timer+719528*24*3600)),
  {ts_datetime,{{Year, Month, Day},{Hour, Minute, Second},000000}}.

%%--------------------------------------------------------
-spec convert(ts_type(),ts_timestamp())-> ts_timestamp().
%%内部类型转换 <<"20170328092855603000">>
convert(ts_binary, Timestamp) ->
  {ts_datetime,{{Year, Month, Day},{Hour, Minute, Second},MicroSec}} = to_ts_datetime(Timestamp),
  TimestampList = lists:flatten(
    io_lib:format("~4..0w~2..0w~2..0w~2..0w~2..0w~2..0w~6..0w",
    [Year, Month, Day, Hour, Minute, Second, MicroSec])),
  {ts_binary,list_to_binary(TimestampList)};
convert(ts_datetime, Timestamp) ->
  to_ts_datetime(Timestamp);
%内部类型转换 <<"20170328T09:29:23">>
convert(ts_tz, Timestamp) ->
  {ts_datetime,{{Year, Month, Day},{Hour, Minute, Second},_MicroSec}} = to_ts_datetime(Timestamp),
  TimestampList = lists:flatten(
    io_lib:format("~4..0w~2..0w~2..0wT~2..0w:~2..0w:~2..0w",
      [Year, Month, Day, Hour, Minute, Second])),
  {ts_tz,list_to_binary(TimestampList)};
%内部类型转换 <<"2017-03-28T09:30:03.978000Z">>
convert(ts_tz_ali, Timestamp) ->
  {ts_datetime,{{Year, Month, Day},{Hour, Minute, Second},MicroSec}} = to_ts_datetime(Timestamp),
  TimestampList = lists:flatten(
      io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0w.~6..0wZ",
        [Year, Month, Day, Hour, Minute, Second, MicroSec])),
  {ts_tz_ali,list_to_binary(TimestampList)};
convert(ts_unix, Timestamp) ->
  {ts_datetime,{{Year, Month, Day},{Hour, Minute, Second},_MicroSec}} = to_ts_datetime(Timestamp),
  Un_time = calendar:local_time_to_universal_time({{Year, Month, Day}, {Hour, Minute, Second}}),
  {ts_unix,calendar:datetime_to_gregorian_seconds(Un_time)-719528*24*3600};
convert(ts_epoch, Timestamp) ->
  {ts_datetime,{{Year, Month, Day},{Hour, Minute, Second},_MicroSec}} = to_ts_datetime(Timestamp),
  Un_time = calendar:local_time_to_universal_time({{Year, Month, Day}, {Hour, Minute, Second}}),
  {ts_epoch,calendar:datetime_to_gregorian_seconds(Un_time)-719528*24*3600}.

convert_test()->
  ?assertEqual({ts_binary,<<"20170328092855603000">>},convert(ts_binary,{ts_binary,<<"20170328092855603000">>})),
  ?assertEqual({ts_datetime,{{2017,3,28},{9,29,8},197000}},convert(ts_datetime,{ts_datetime,{{2017,3,28},{9,29,8},197000}})),
  ?assertEqual({ts_tz,<<"20170328T09:29:23">>},convert(ts_tz,{ts_tz,<<"20170328T09:29:23">>})),
  ?assertEqual({ts_tz_ali,<<"2017-03-28T09:30:03.978000Z">>},convert(ts_tz_ali,{ts_tz_ali,<<"2017-03-28T09:30:03.978000Z">>})),
  ?assertEqual({ts_unix,1490682672},convert(ts_unix,{ts_unix,1490682672})),
  ?assertEqual({ts_epoch,1490682672},convert(ts_epoch,{ts_epoch,1490682672})).

%%--------------------------------------------------------
-spec to_datetime(dt_type(),ts_timestamp())-> datetime_type().
%% date_yyyymmdd
to_datetime(date_yyyymmdd, Timestamp) ->
  {ts_datetime,{{Year, Month, Day},{_Hour, _Minute, _Second},_MicroSec}} = to_ts_datetime(Timestamp),
  TimestampList = lists:flatten(
    io_lib:format("~4..0w~2..0w~2..0w",
      [Year, Month, Day])),
  {date_yyyymmdd,list_to_binary(TimestampList)};
%% date_mmdd
to_datetime(date_mmdd, Timestamp) ->
  {ts_datetime,{{_Year, Month, Day},{_Hour, _Minute, _Second},_MicroSec}} = to_ts_datetime(Timestamp),
  TimestampList = lists:flatten(
    io_lib:format("~2..0w~2..0w",
      [Month, Day])),
  {date_mmdd,list_to_binary(TimestampList)};
%% date_internal
to_datetime(date_internal, Timestamp) ->
  {ts_datetime,{{Year, Month, Day},{_Hour, _Minute, _Second},_MicroSec}} = to_ts_datetime(Timestamp),
  {date_internal,{Year,Month,Day}};
%% time_hhmmss
to_datetime(time_hhmmss, Timestamp) ->
  {ts_datetime,{{_Year, _Month, _Day},{Hour, Minute, Second},_MicroSec}} = to_ts_datetime(Timestamp),
  TimestampList = lists:flatten(
    io_lib:format("~2..0w~2..0w~2..0w",
      [Hour, Minute, Second])),
  {time_hhmmss,list_to_binary(TimestampList)};
%% time_internal
to_datetime(time_internal, Timestamp) ->
  {ts_datetime,{{_Year, _Month, _Day},{Hour, Minute, Second},_MicroSec}} = to_ts_datetime(Timestamp),
  {time_internal,{Hour,Minute,Second}}.

to_datetime_test()->
  ?assertEqual({date_yyyymmdd,<<"20170328">>},to_datetime(date_yyyymmdd,{ts_binary,<<"20170328092855603000">>})),
  ?assertEqual({date_mmdd,<<"0328">>},to_datetime(date_mmdd,{ts_datetime,{{2017,3,28},{9,29,8},197000}})),
  ?assertEqual({date_internal,{2017,3,28}},to_datetime(date_internal,{ts_tz,<<"20170328T09:29:23">>})),
  ?assertEqual({time_hhmmss,<<"093003">>},to_datetime(time_hhmmss,{ts_tz_ali,<<"2017-03-28T09:30:03.978000Z">>})),
  ?assertEqual({time_internal,{14,31,12}},to_datetime(time_internal,{ts_unix,1490682672})).