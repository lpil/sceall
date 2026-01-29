-module(sceall_ffi).
-export([open_port/2, close_port/1, command_port/2, convert_message/1]).

open_port(A, O) ->
    try
        {ok, erlang:open_port(A, O)}
    catch
        error:system_limit -> {error, not_enough_beam_ports};
        error:enomem -> {error, not_enough_memory};
        error:eagain -> {error, not_enough_os_processes};
        error:enametoolong -> {error, external_command_too_long};
        error:emfile -> {error, not_enough_file_descriptors};
        error:enfile -> {error, os_file_table_full};
        error:eacces -> {error, file_not_executable};
        error:enoent -> {error, file_does_not_exist}
    end.

close_port(Port) ->
    try
        erlang:port_close(Port)
    catch
        error:badarg -> false
    end.

command_port(Port, Data) ->
    try erlang:port_command(Port, Data) of
        true -> {ok, nil};
        false -> {error, send_was_aborted}
    catch
        error:badarg -> {error, cannot_send_to_exited_program}
    end.

convert_message(Message) ->
    case Message of
        {Port, {data, Data}} -> {data, {program_handle, Port}, Data};
        {Port, {exit_status, Status}} -> {exited, {program_handle, Port}, Status}
    end.
