# Filtering

The filter bar supports advanced syntax to whittle down jobs based on multiple fields. All
searches require a qualifier to narrow criteria for fast queries. While the exact-match qualifier
syntax is more restrictive than full text searching, it is **vastly faster** in most situations
and always indexable.

> ### Query Limits {: .info}
>
> To minimize load, only the **most recent 100k jobs** are searched (approximately, across all
> states). Use the `c:Oban.Web.Resolver.jobs_query_limit/1` callback to configure a different
> general or per state limit, or disable limiting entirely.

## Qualifiers

Qualifiers are used to target a specific `Oban.Job` field. The available qualifiers are:

| Qualifier     | Description            | Example                 |
| ------------- | ---------------------- | ----------------------- |
| `args.`       | a key or value in args | `args.id:123`           |
| `meta.`       | a kye or value in meta | `meta.batch_id:123`     |
| `nodes:`      | host name              | `nodes:worker@somehost` |
| `priorities:` | number from 0 to 3     | `priorities:1`          |
| `queues:`     | queue name             | `queues:default`        |
| `tags:`       | tag name               | `tags:super,duper`      |
| `workers`     | worker module name     | `workers:MyApp.Worker`  |

## Nested Args/Meta Paths

The structured `jsonb` fields, `args` and `meta`, require searching in a path specified with a
"dot" syntax. For example:

* `args.user.plan.name:business`
* `meta.worker_id:123`
* `meta.batch_callback_args.some_id:123`

To aid in path construction and value matching the filter combobox will suggest paths after a `.`
and values at that path after a `:`.

> #### Multiple Values {: .info}
> 
> Comma separation doesn't work for `args` or `meta` filters. That's because they use a highly
> optimized containment query which doesn't support multiple values.

## Quoted Searches

If your search query contains whitespace or punctuation you need to surround it with quotation
marks. For example:

* `args.address.city:"New York City"`

In practice this isn't much of an issue because only `args` or `meta` may contain whitespace
anyhow.

You can't use the following characters as part of your search query:

`, : ; / \ ' = * ! ? # $ & + ^ | ~ < > ( ) { } [ ]`

The search will strip these symbols and ignore them.

## Suggestion Caching

Suggestions are lazily fetched and cached for subsequent lookups. By default, suggestion queries
are limited to the most recent 10k jobs to minimize database load. You can change the limit with
the `c:Oban.Web.Resolver.hint_query_limit/1` callback in a custom resolver.

Cached items are purged after a fixed 5 minute period, which isn't configurable.
