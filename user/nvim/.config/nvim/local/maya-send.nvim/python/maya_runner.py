"""Executed inside Maya to run a chunk of code sent from Neovim.

Neovim appends a `_nvim_maya_run(...)` call to a copy of this file and asks
Maya's commandPort to exec it, so everything here must be importable and
runnable standalone in Maya's interpreter.
"""

import __main__
import ast
import contextlib
import sys
import traceback


class _NvimMayaTee:
    def __init__(self, maya_stream, log_stream):
        self._maya_stream = maya_stream
        self._log_stream = log_stream

    def write(self, text):
        if not isinstance(text, str):
            text = str(text)

        self._maya_stream.write(text)
        self._log_stream.write(text)
        self._log_stream.flush()
        return len(text)

    def flush(self):
        self._maya_stream.flush()
        self._log_stream.flush()

    def __getattr__(self, name):
        return getattr(self._maya_stream, name)


def _nvim_maya_run(code_path, output_path):
    namespace = __main__.__dict__

    # Temporary global used by the transformed final expression
    hook_name = "__nvim_maya_displayhook_7f43c1__"
    missing = object()
    previous_hook = namespace.get(hook_name, missing)
    namespace[hook_name] = sys.__displayhook__

    try:
        with open(output_path, "a", encoding="utf-8", buffering=1) as log:
            log.write("\n--- Maya send ---\n")

            stdout_tee = _NvimMayaTee(sys.stdout, log)
            stderr_tee = _NvimMayaTee(sys.stderr, log)

            with contextlib.redirect_stdout(stdout_tee), contextlib.redirect_stderr(stderr_tee):
                try:
                    with open(code_path, "r", encoding="utf-8") as source_file:
                        source = source_file.read()

                    tree = ast.parse(source, filename=code_path, mode="exec")

                    # Turn the final bare expression into:
                    # sys.displayhook(expression)
                    #
                    # This prints repr(result), suppresses None and updates "_",
                    # matching normal interactive Python behaviour.
                    if tree.body and isinstance(tree.body[-1], ast.Expr):
                        last = tree.body[-1]

                        replacement = ast.Expr(
                            value=ast.Call(
                                func=ast.Name(id=hook_name, ctx=ast.Load()),
                                args=[last.value],
                                keywords=[],
                            )
                        )

                        tree.body[-1] = ast.copy_location(replacement, last)
                        ast.fix_missing_locations(tree)

                    exec(
                        compile(tree, code_path, "exec"),
                        namespace,
                        namespace,
                    )

                except BaseException:
                    traceback.print_exc()

    finally:
        if previous_hook is missing:
            namespace.pop(hook_name, None)
        else:
            namespace[hook_name] = previous_hook
