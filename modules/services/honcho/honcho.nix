{
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.honcho = {
    url = "github:plastic-labs/honcho";
    flake = false;
  };
  den.aspects.honcho.darwin = {
    config,
    pkgs,
    ...
  }: let
    state = "/var/lib/honcho";
    database = "${state}/postgresql";
    socket = "${state}/run";
    package = import ./_package.nix {
      inherit pkgs lib;
      source = inputs.honcho;
      hermesInput = inputs.hermes-agent;
    };
    postgres = pkgs.postgresql_17.withPackages (p: [p.pgvector]);
    hba = pkgs.writeText "honcho-pg_hba.conf" ''
      local all postgres peer map=bootstrap
      local honcho honcho peer map=application
      local all all reject
      host all all 0.0.0.0/0 reject
      host all all ::/0 reject
    '';
    ident = pkgs.writeText "honcho-pg_ident.conf" ''
      bootstrap _postgres postgres
      application augusto honcho
    '';
    pgConfig = pkgs.writeText "honcho-postgresql.conf" ''
      listen_addresses = ${"''"}
      unix_socket_directories = '${socket}'
      unix_socket_permissions = 0777
      hba_file = '${hba}'
      ident_file = '${ident}'
    '';
    pgStart = pkgs.writeShellScript "honcho-postgresql" ''
      set -eu
      [ "$(/usr/bin/stat -f %Su ${database})" = _postgres ]
      if [ -f ${database}/PG_VERSION ]; then
        [ "$(cat ${database}/PG_VERSION)" = 17 ] || { echo 'Unexpected PostgreSQL version; refusing upgrade' >&2; exit 1; }
      else
        [ -z "$(find ${database} -mindepth 1 -maxdepth 1 -print)" ] || { echo 'Refusing nonempty PostgreSQL directory' >&2; exit 1; }
        ${postgres}/bin/initdb -D ${database} -U postgres --encoding=UTF8 --auth-local=reject --auth-host=reject
      fi
      exec ${postgres}/bin/postgres -D ${database} -c config_file=${pgConfig}
    '';
    pgBootstrap = pkgs.writeShellScript "honcho-database-bootstrap" ''
      set -eu
      until ${postgres}/bin/psql -h ${socket} -U postgres -d postgres -X -Atqc 'SELECT 1' >/dev/null 2>&1; do sleep 2; done
      ${postgres}/bin/psql -h ${socket} -U postgres -d postgres -X -v ON_ERROR_STOP=1 <<'SQL'
      DO $$ BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='honcho') THEN
          CREATE ROLE honcho LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
        END IF;
        IF EXISTS (SELECT FROM pg_roles WHERE rolname='honcho' AND (rolsuper OR rolcreatedb OR rolcreaterole OR NOT rolcanlogin)) THEN
          RAISE EXCEPTION 'Unexpected privileges on existing honcho role';
        END IF;
      END $$;
      SELECT $sql$CREATE DATABASE honcho OWNER honcho ENCODING 'UTF8' TEMPLATE template0$sql$
      WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname='honcho')\gexec
      DO $$ BEGIN
        IF EXISTS (SELECT FROM pg_database WHERE datname='honcho' AND pg_get_userbyid(datdba)<>'honcho') THEN
          RAISE EXCEPTION 'Unexpected owner on existing honcho database';
        END IF;
        IF EXISTS (SELECT FROM pg_database WHERE datname='honcho' AND pg_encoding_to_char(encoding)<>'UTF8') THEN
          RAISE EXCEPTION 'Existing honcho database is not UTF8; migrate it before starting Honcho';
        END IF;
      END $$;
      SQL
      ${postgres}/bin/psql -h ${socket} -U postgres -d honcho -X -v ON_ERROR_STOP=1 <<'SQL'
      CREATE EXTENSION IF NOT EXISTS vector;
      CREATE EXTENSION IF NOT EXISTS pg_trgm;
      CREATE EXTENSION IF NOT EXISTS btree_gin;
      SQL
    '';
    prefixes = [
      "DERIVER_MODEL_CONFIG"
      "SUMMARY_MODEL_CONFIG"
      "DIALECTIC_LEVELS__minimal__MODEL_CONFIG"
      "DIALECTIC_LEVELS__low__MODEL_CONFIG"
      "DIALECTIC_LEVELS__medium__MODEL_CONFIG"
      "DIALECTIC_LEVELS__high__MODEL_CONFIG"
      "DIALECTIC_LEVELS__max__MODEL_CONFIG"
      "DREAM_DEDUCTION_MODEL_CONFIG"
      "DREAM_INDUCTION_MODEL_CONFIG"
    ];
    environment =
      {
        HOME = "${state}/app";
        XDG_CACHE_HOME = "${state}/app/cache";
        PYTHONPATH = "${inputs.honcho}";
        PYTHONDONTWRITEBYTECODE = "1";
        PGHOST = socket;
        DB_CONNECTION_URI = "postgresql+psycopg://honcho@/honcho?host=%2Fvar%2Flib%2Fhoncho%2Frun";
        DB_SCHEMA = "public";
        VECTOR_STORE_TYPE = "pgvector";
        DERIVER_WORKERS = "1";
        # Fact extraction must return JSON, not spend its output budget on thinking.
        DERIVER_MODEL_CONFIG__THINKING_EFFORT = "none";
        CACHE_ENABLED = "false";
        AUTH_USE_AUTH = "true";
        TELEMETRY_ENABLED = "false";
        SENTRY_ENABLED = "false";
        METRICS_ENABLED = "false";
        LLM_OPENAI_API_KEY = "ollama";
        HONCHO_KEYS_DIR = "${state}/app/keys";
        EMBEDDING_MODEL_CONFIG__TRANSPORT = "openai";
        EMBEDDING_MODEL_CONFIG__MODEL = "qwen3-embedding:0.6b";
        EMBEDDING_MODEL_CONFIG__OVERRIDES__BASE_URL = "http://127.0.0.1:11434/v1";
        EMBEDDING_VECTOR_DIMENSIONS = "1024";
        EMBEDDING_MODEL_CONFIG__DIMENSIONS_MODE = "never";
        EMBEDDING_MODEL_CONFIG__ENCODING_FORMAT_MODE = "float";
      }
      // builtins.listToAttrs (lib.concatMap (prefix: [
          {
            name = "${prefix}__TRANSPORT";
            value = "openai";
          }
          {
            name = "${prefix}__MODEL";
            value = "gemma4:12b-mlx";
          }
          {
            name = "${prefix}__OVERRIDES__BASE_URL";
            value = "http://127.0.0.1:11434/v1";
          }
        ])
        prefixes);
    secret = config.sops.secrets.honcho_jwt_secret.path;
    loadSecret = ''
      set -eu
      umask 077
      for _ in $(seq 1 60); do [ -r ${secret} ] && break; sleep 2; done
      export AUTH_JWT_SECRET="$(cat ${secret})"
      [ -n "$AUTH_JWT_SECRET" ]
    '';
    api = pkgs.writeShellScript "honcho-api" ''
      ${loadSecret}
      ${package.python}/bin/python ${./_bootstrap.py} prepare
      ${package.python}/bin/python -m src.migrate head
      ${package.python}/bin/python scripts/configure_embeddings.py --yes
      exec ${package.python}/bin/python -m uvicorn src.main:app --host 127.0.0.1 --port 8001 --workers 1
    '';
    worker = pkgs.writeShellScript "honcho-worker" ''
      ${loadSecret}
      ${package.python}/bin/python ${./_bootstrap.py} provision
      exec ${package.python}/bin/python -m src.deriver
    '';
  in {
    sops.secrets.honcho_jwt_secret = {owner = "augusto";};
    launchd.daemons.honcho-postgresql = {
      command = "${pgStart}";
      serviceConfig = {
        UserName = "_postgres";
        GroupName = "_postgres";
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${state}/postgresql.log";
        StandardErrorPath = "${state}/postgresql.log";
      };
    };
    launchd.daemons.honcho-database-bootstrap = {
      command = "${pgBootstrap}";
      serviceConfig = {
        UserName = "_postgres";
        GroupName = "_postgres";
        RunAtLoad = true;
        KeepAlive = {SuccessfulExit = false;};
        StandardOutPath = "${state}/bootstrap.log";
        StandardErrorPath = "${state}/bootstrap.log";
      };
    };
    launchd.daemons.honcho-api = {
      command = "${api}";
      inherit environment;
      serviceConfig = {
        UserName = "augusto";
        WorkingDirectory = "${inputs.honcho}";
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${state}/app/api.log";
        StandardErrorPath = "${state}/app/api.log";
      };
    };
    launchd.daemons.honcho-worker = {
      command = "${worker}";
      inherit environment;
      serviceConfig = {
        UserName = "augusto";
        WorkingDirectory = "${inputs.honcho}";
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${state}/app/worker.log";
        StandardErrorPath = "${state}/app/worker.log";
      };
    };
    system.activationScripts.postActivation.text = ''
      mkdir -p ${state}
      for dir in ${database} ${socket}; do
        if [ -e "$dir" ]; then
          [ "$(/usr/bin/stat -f %Su "$dir")" = _postgres ] || { echo "Foreign owner: $dir" >&2; exit 1; }
        else
          install -d -o _postgres -g _postgres "$dir"
        fi
      done
      chmod 0700 ${database}
      chmod 0755 ${socket}
      install -d -m 0700 -o augusto -g staff ${state}/app ${state}/app/keys ${state}/app/cache
      touch ${state}/postgresql.log ${state}/bootstrap.log
      chown _postgres:_postgres ${state}/postgresql.log ${state}/bootstrap.log
    '';
  };
}
