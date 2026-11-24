let
  codex = model: {
    provider = "openai-codex";
    default = model;
  };
  claude = model: {
    provider = "claude-subscription-directsdk-experimental";
    default = model;
  };
  ollama = {
    provider = "custom";
    default = "deepseek-v4-pro:cloud";
    base_url = "http://127.0.0.1:11434/v1";
    context_length = 65536;
  };
in {
  laptop = {
    default = codex "gpt-6-luna";
    librarian = codex "gpt-6-astra";
    coordinator = codex "gpt-6-astra";
    programmer = claude "claude-opus-5-5[1m]";
    reviewer = codex "gpt-6-astra";
    qa = claude "claude-sonnet-5-5[1m]";
    research = claude "claude-opus-5-5[1m]";
    assistant = claude "claude-sonnet-5-5[1m]";
  };
  macmini = {
    default = ollama;
    coordinator = ollama;
    programmer = ollama;
    reviewer = ollama;
    qa = ollama;
    research = ollama;
    assistant = ollama;
    livia = ollama;
    librarian-livia = ollama;
  };
}
