import gleam/dynamic.{type Dynamic}
import gleam/erlang/charlist.{type Charlist}
import gleam/erlang/port.{type Port}
import gleam/erlang/process.{type Selector}
import gleam/list
import gleam/result

/// A reference to the spawned program.
///
pub opaque type ProgramHandle {
  ProgramHandle(port: Port)
}

/// Messages that will be sent to the BEAM process that called the
/// `spawn_program` function. These can be received using the `select`
/// function.
///
pub type ProgramMessage {
  /// Data that the program printed to stdout or stderr.
  ///
  /// Be aware, data printed could be too large or printed too slowly for one
  /// message! In these cases, the data will be delivered over multiple
  /// messages.
  ///
  Data(program: ProgramHandle, data: BitArray)
  /// The program exited.
  Exited(program: ProgramHandle, status_code: Int)
}

pub type SpawnProgramError {
  /// There are not enough beam ports available.
  NotEnoughBeamPorts

  /// There is insufficient memory to spawn the executable.
  NotEnoughMemory

  /// There are not enough OS processes available.
  NotEnoughOsProcesses

  /// The external command is too long to execute.
  ExternalCommandTooLong

  /// There are not enough file descriptors available.
  NotEnoughFileDescriptors

  /// The OS file table is full.
  OsFileTableFull

  /// The file at the given path could not be executed.
  FileNotExecutable

  /// No file exists at the given path.
  FileDoesNotExist
}

pub type SendError {
  /// The port send operation was aborted
  SendWasAborted
  /// The program has already exited
  CannotSendToExitedProgram
}

type ErlangPortName {
  SpawnExecutable(Charlist)
}

type ErlangPortOption {
  Args(List(Charlist))
  Env(List(#(Charlist, Charlist)))
  UseStdio
  Binary
  ExitStatus
  StderrToStdout
  Cd(Charlist)
}

@external(erlang, "sceall_ffi", "open_port")
fn erlang_open_port(
  name: ErlangPortName,
  options: List(ErlangPortOption),
) -> Result(Port, SpawnProgramError)

@external(erlang, "sceall_ffi", "close_port")
fn erlang_close_port(port: Port) -> Bool

@external(erlang, "sceall_ffi", "command_port")
fn erlang_command_port(port: Port, data: BitArray) -> Result(Nil, SendError)

@external(erlang, "sceall_ffi", "convert_message")
fn unsafely_convert_message(data: Dynamic) -> ProgramMessage

@external(erlang, "sceall_ffi", "find_executable")
fn erlang_find_executable(name: Charlist) -> Result(Charlist, Nil)

/// Spawn an operating system, returning a reference to it that can be used to
/// receive stdio data as messages.
///
/// There is no `PATH` variable resolution, so you cannot give the name of a
/// program. It must be a path to the executable.
///
/// The process that calls this function is the owner of the BEAM port for the
/// spawned program. When this process exits the port and the program will be
/// shut down.
///
pub fn spawn_program(
  executable_path path: String,
  working_directory directory: String,
  command_line_arguments arguments: List(String),
  environment_variables environment: List(#(String, String)),
) -> Result(ProgramHandle, SpawnProgramError) {
  let path = charlist.from_string(path)
  let directory = charlist.from_string(directory)
  let arguments = list.map(arguments, charlist.from_string)
  let environment =
    list.map(environment, fn(pair) {
      #(charlist.from_string(pair.0), charlist.from_string(pair.1))
    })
  erlang_open_port(SpawnExecutable(path), [
    Args(arguments),
    Cd(directory),
    Env(environment),
    UseStdio,
    Binary,
    ExitStatus,
    StderrToStdout,
  ])
  |> result.map(ProgramHandle)
}

/// Exit a program. Returns `True` if the program was stopped, returns `False`
/// if the program had already stopped.
///
/// The `Exited` message will not be sent if the program is stopped with this
/// function.kj
///
pub fn exit_program(program: ProgramHandle) -> Bool {
  erlang_close_port(program.port)
}

/// Send some data to stdin of the program.
///
/// Sending is synchronous, with the sending process blocking until the
/// operation completes.
///
pub fn send(program: ProgramHandle, data: BitArray) -> Result(Nil, SendError) {
  erlang_command_port(program.port, data)
}

/// Add a message handler for messages from the spawned program. See
/// `ProgramMessage` for details.
///
/// Use this to handle program messages in your actor!
///
pub fn select(
  selector: Selector(message),
  program: ProgramHandle,
  mapper: fn(ProgramMessage) -> message,
) -> Selector(message) {
  process.select_record(selector, program.port, 1, fn(data) {
    data |> unsafely_convert_message |> mapper
  })
}

/// Get the BEAM port for a given program.
///
pub fn program_port(handle: ProgramHandle) -> Port {
  handle.port
}

/// Find the path to a program given it's name.
///
/// Returns an error if no such executable could be found in the `PATH`.
///
pub fn find_executable(name: String) -> Result(String, Nil) {
  name
  |> charlist.from_string
  |> erlang_find_executable
  |> result.map(charlist.to_string)
}
