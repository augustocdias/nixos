# Agent half of the kanban-transcripts plugin. desktop/ is linked on its own into
# ~/.hermes/desktop-plugins: Desktop's automatic copy of a package's desktop half fails on read-only store directories.
{lib}:
lib.cleanSourceWith {
  name = "kanban-transcripts";
  src = ./kanban-transcripts;
  filter = path: _: !(lib.elem (baseNameOf path) ["desktop" "__pycache__"]);
}
