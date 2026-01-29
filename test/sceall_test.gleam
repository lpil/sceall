import gleam/bit_array
import gleam/erlang/process
import gleam/function
import gleam/string
import gleeunit
import sceall

pub fn main() -> Nil {
  gleeunit.main()
}

fn test_selector() -> process.Selector(a) {
  process.new_selector()
  |> process.select_other(fn(x) {
    panic as { "unexpected message: " <> string.inspect(x) }
  })
}

pub fn readme_example_test() {
  // Spawn the `cat` program, which is typically available on Unix-like
  // operating systems.
  //
  // In this example we always use `let assert`, but in a real program 
  // you would want to handle any errors.
  let assert Ok(program) =
    sceall.spawn_program(
      executable_path: "/bin/cat",
      working_directory: "./",
      command_line_arguments: [],
      environment_variables: [],
    )

  // We can send data to the running program. The `cat` program will 
  // print any data it receives.
  let assert Ok(_) = sceall.send(program, <<"Hello, Joe!\n">>)
  let assert Ok(_) = sceall.send(program, <<"Hello, Mike!\n">>)

  // The stdout and stderr of the program is sent back using BEAM messages.
  //
  // A selector is used to receive these messages. If you are not familiar
  // with selectors check out the documentation for `gleam_erlang`.
  let selector =
    process.new_selector() |> sceall.select(program, function.identity)

  assert process.selector_receive(selector, 200)
    == Ok(sceall.Data(program, <<"Hello, Joe!\nHello, Mike!\n">>))

  // If the program exited itself we would get a `sceall.Exited` message,
  // which would contain the status code. `cat` doesn't exit by itself,
  // so we can use the `exit_program` function instead.
  sceall.exit_program(program)
}

pub fn unknown_executable_test() {
  assert sceall.spawn_program("/wibble", ".", [], [])
    == Error(sceall.FileDoesNotExist)
}

pub fn not_executable_test() {
  assert sceall.spawn_program("./gleam.toml", ".", [], [])
    == Error(sceall.FileNotExecutable)
}

pub fn unknown_directory_test() {
  let assert Ok(program) =
    sceall.spawn_program("/bin/echo", "/does/not/exist", [], [])

  let selector = test_selector() |> sceall.select(program, function.identity)

  assert process.selector_receive(selector, 200)
    == Ok(sceall.Exited(program, 2))

  assert !sceall.exit_program(program)
}

pub fn echo_hello_test() {
  let assert Ok(program) =
    sceall.spawn_program("/bin/echo", "./", ["Hello, Joe!"], [])
  let selector = test_selector() |> sceall.select(program, function.identity)

  assert process.selector_receive(selector, 200)
    == Ok(sceall.Data(program, <<"Hello, Joe!\n">>))

  assert process.selector_receive(selector, 200)
    == Ok(sceall.Exited(program, 0))

  assert !sceall.exit_program(program)
}

pub fn cat_send_test() {
  let assert Ok(program) = sceall.spawn_program("/bin/cat", "./", [], [])
  let selector = test_selector() |> sceall.select(program, function.identity)

  assert sceall.send(program, <<"Hello, Joe!\n">>) == Ok(Nil)
  assert sceall.send(program, <<"Hello, Mike!\n">>) == Ok(Nil)

  assert process.selector_receive(selector, 200)
    == Ok(sceall.Data(program, <<"Hello, Joe!\nHello, Mike!\n">>))

  assert sceall.exit_program(program)
  assert !sceall.exit_program(program)
}

pub fn env_test() {
  let assert Ok(program) =
    sceall.spawn_program("/usr/bin/env", "./", [], [
      #("gleam-wibble", "123"),
      #("gleam-wobble", "456"),
    ])
  let selector = test_selector() |> sceall.select(program, function.identity)

  let assert Ok(sceall.Data(_program, data)) =
    process.selector_receive(selector, 200)
  assert process.selector_receive(selector, 200)
    == Ok(sceall.Exited(program, 0))

  let assert Ok(data) = bit_array.to_string(data)
  assert string.contains(data, "gleam-wibble=123")
  assert string.contains(data, "gleam-wobble=456")

  assert !sceall.exit_program(program)
}

pub fn cwd_test() {
  let assert Ok(program) = sceall.spawn_program("/bin/pwd", "/", [], [])
  let selector = test_selector() |> sceall.select(program, function.identity)

  assert process.selector_receive(selector, 200)
    == Ok(sceall.Data(program, <<"/\n">>))
  assert process.selector_receive(selector, 200)
    == Ok(sceall.Exited(program, 0))

  assert !sceall.exit_program(program)
}

pub fn exit_test() {
  let assert Ok(program) = sceall.spawn_program("/bin/sleep", "./", ["10"], [])
  let selector = test_selector() |> sceall.select(program, function.identity)

  assert sceall.exit_program(program)
  assert !sceall.exit_program(program)
  assert process.selector_receive(selector, 200) == Error(Nil)
}

pub fn find_executable_not_found_test() {
  assert sceall.find_executable("not-a-known-program") == Error(Nil)
}

pub fn find_executable_cat_test() {
  assert sceall.find_executable("cat") == Ok("/bin/cat")
}
