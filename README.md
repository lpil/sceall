# Sceall

Spawn OS processes and stream their stdio on the BEAM!

[![Package Version](https://img.shields.io/hexpm/v/sceall)](https://hex.pm/packages/sceall)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/sceall/)

```sh
gleam add sceall@1
```
```gleam
pub fn main() {
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
```

Documentation can be found at <https://hexdocs.pm/sceall>.

## Name

Sceall means shell in Gaeilge.

It has 1 syllable. _sc_ as in the start of "skew", _eall_ as in the end of
"pal". Kinda like "skull" but with an "a" instead of a "u".
