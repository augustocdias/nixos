let
  codex = model: [
    {
      provider = "openai-codex";
      inherit model;
    }
  ];
  claude = model: [
    {
      provider = "claude-subscription-directsdk-experimental";
      inherit model;
    }
  ];
  ollama = [
    {
      provider = "custom";
      model = "deepseek-v4.1-flash:cloud";
      base_url = "http://127.0.0.1:11434/v1";
    }
  ];
in {
  laptop = {
    default = claude "claude-sonnet-5-5[1m]";
    coordinator = claude "claude-fable-5-2[1m]";
    programmer = codex "gpt-6.1-sol";
    reviewer = claude "claude-fable-5-2[1m]";
    qa = codex "gpt-6-astra";
    research = codex "gpt-6.1-sol";
    assistant = codex "gpt-6-astra";
  };
  macmini = {
    default = ollama;
    coordinator = ollama;
    programmer = ollama;
    reviewer = ollama;
    qa = ollama;
    research = ollama;
    assistant = ollama;
    augusto = ollama;
    livia = ollama;
  };
}
