;; extends

;; Sqlx functions
(
 (call_expression
  function: [
    ;; e.g. query
    (identifier) @id
    ;; e.g. sqlx::query
    (scoped_identifier
      name: (identifier) @id
    )
  ]

  (#any-of? @id "query_as" "query")

  arguments: (arguments
    (_)*
    [
      (raw_string_literal
        (string_content) @injection.content
      )
      (string_literal
        (string_content) @injection.content
      )
    ]
    (_)*
  ))

  (#set! injection.language "sql")
)

;; Sqlx macros
(
 (macro_invocation
  macro: [
    ;; e.g. query!
    (identifier) @macro_name
    ;; e.g. sqlx::query!
    (scoped_identifier
      name: (identifier) @macro_name
    )
  ]

  (#any-of? @macro_name "query" "query_as")

  (token_tree
    (_)*
    [
      (raw_string_literal
        (string_content) @injection.content
      )
      (string_literal
        (string_content) @injection.content
      )
    ]
    (_)*
  )
 )

 (#set! injection.language "sql")
)

