{fetchurl}: let
  ghRaw = {
    repo,
    rev,
    path,
    hash,
  }:
    fetchurl {
      url = "https://raw.githubusercontent.com/${repo}/${rev}/${path}";
      inherit hash;
    };
in {
  # Attr name is the Open WebUI tool id (its primary key). It must match the
  # id already in the tool table, or the importer adds a second copy.
  sub_agent = {
    name = "Sub Agent";
    src = ghRaw {
      repo = "Skyzi000/open-webui-extensions";
      rev = "d6d1e1c020d3643b536cfc4577d155c1c078e194";
      path = "tools/sub_agent.py";
      hash = "sha256-66cOY/xXaDKGTRI/+5Z88/Qin9O587L7QzK3ZRUmfrk=";
    };
  };

  parallel_tools = {
    name = "Parallel Tools";
    src = ghRaw {
      repo = "Skyzi000/open-webui-extensions";
      rev = "7211d0563ee0a931ed2bbbaabdbb3a80d6b80141";
      path = "tools/parallel_tools.py";
      hash = "sha256-FsI2HVXBay0WBpt+ZULXfF5cJgE/+3lGC1CCUmpQjxw=";
    };
  };

  wikipedia_tool = {
    name = "Wikipedia Tool";
    src = ghRaw {
      repo = "iChristGit/OpenWebui-Tools";
      rev = "d369f369f87f9b7d8111c4e18d753aa2abdebcbf";
      path = "Tools/wiki.py";
      hash = "sha256-so79nIvYT+hIE3RR6Vej+S7aPlYaQAqPmFbJm91zCho=";
    };
  };

  ask_user = {
    name = "Ask User";
    src = ghRaw {
      repo = "iChristGit/OpenWebui-Tools";
      rev = "be2c1c2cb9b5b532b6f605e165af0d7ad93e7438";
      path = "Tools/ask-user.py";
      hash = "sha256-cOU2KkHgDlFOExBx/CbC8R+FLNmLdvyJzkELLcXM3Lg=";
    };
  };

  osm = {
    name = "OpenStreetMap Tool";
    src = ghRaw {
      repo = "ProjectMoon/open-webui-filters";
      rev = "2add69458bd5f64f97be34eab058b6e8df3b9e9f";
      path = "osm.py";
      hash = "sha256-iT1OyuYq8CX5LxTMLbQYnlnStFWCWsda1rH1lNmyqy0=";
    };
  };
}
