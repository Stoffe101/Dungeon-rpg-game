# Agents working on Kindled Deep

Read `CLAUDE.md` first. Its rule "Background runs only (mandatory)" applies to every agent:
start Godot only through `tools/dev/bg.py`, which keeps windows off-screen, unfocused and silent,
and works from a copy of the project with its own user folder. Never kill Godot processes you did
not start, never touch the owner's saves, and never take focus on this PC.
