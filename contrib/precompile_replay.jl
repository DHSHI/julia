import REPL
include(joinpath(Sys.STDLIB, "REPL", "test", "FakeTerminals.jl"))
import .FakeTerminals.FakeTerminal
include(joinpath(Sys.STDLIB, "REPL", "test", "fake_repl.jl"))

const CTRL_C = '\x03'
const UP_ARROW = "\e[A"
const DOWN_ARROW = "\e[B"

# TODO: Have a utility to generate this from a real REPL session?
precompile_script = """
2+2
println("Hello")
@time 1+1
?reinterpret
;ls
using Ra\t$CTRL_C
\\alpha\t$CTRL_C
\e[200~paste here ;)\e[201~"$CTRL_C
$UP_ARROW$DOWN_ARROW
"""

# Writing ^C to the repl will cause sigint, so let's not die on that
ccall(:jl_exit_on_sigint, Cvoid, (Cint,), 0)

fake_repl() do stdin_write, stdout_read, repl
    repl.specialdisplay = REPL.REPLDisplay(repl)
    repl.history_file = false

    repltask = @async begin
        REPL.run_repl(repl)
    end

    global inc = false
    global b = Condition()
    global c = Condition()
    let cmd = "\"Hello REPL\""
        write(stdin_write, "Main.inc || wait(Main.b); r = $cmd; notify(Main.c); r\r")
    end
    inc = true
    notify(b)
    wait(c)

    write(stdin_write, precompile_script)

    s = readavailable(stdout_read)

    # Close REPL ^D
    write(stdin_write, '\x04')
    Base._wait(repltask)

    nothing
end