# Searching Jobs

The search bar supports basic and advanced syntax to whittle down jobs based on
multiple fields. Without any qualifiers, your terms are matched against
`worker`, `args` and `meta` fields using loose matching or `tsquery` checks, as
appropriate.

For more advanced syntax, check the sections below.

_Note: Multi-field advanced searching is only supported for PostgreSQL 11+. For
older versions, only the `worker` is searched_

## Syntax

Here are a few non-trivial examples that combine the available syntax and
demonstrate what's possible:

Search for "alpha" only in the `worker` column:

`alpha in:worker`

Search for "alpha", and _not_ "omega" in `tags` and `worker` columns:

`alpha -omega in:tags,meta`

Search for "alpha" and _not_ "omega" in `tags` column with a high priority:

`alpha not omega in:tags priority:0`

Search for the phrase "super alpha" in `tags` and "pro" under the `account.plan`
keys of the `args` column:

`"super alpha" in:tags pro in:args.account.plan`

### Qualifiers

With the `in:` qualifier you can restrict your search to the `worker`, `args`,
`meta`, `tags`, or any combination of these.

* `foo in:args` — only search within `args`, using a `tsquery` based search
* `foo in:meta` — only search within `meta`, using a `tsquery` based search
* `foo in:tags` — only search within `tags`, using a `tsquery` based search
* `myapp in:worker` — only search within the `worker`, using a loose `ilike` style match

To search through multiple fields, join them together with a comma. For example:

* `foo in:args,meta`
* `foo in:tags,meta,args`
* `foo in:worker,tags`

### Nested Fields

For the `jsonb` fields, `args` and `meta`, you can also use "dot" path syntax to
restrict search to nested data.

* `a1b2c3d4 in:meta.worker_id`
* `business in:args.user.plan.name`

Naturally, you can combine path syntax with multi-field syntax:

* `foo in:args.batch_id,meta.worker_id`
* `foo in:args.user.plan,tags`

### ID Matches

The `id:` qualifier restricts results to one or more jobs by id. Filter down to
multiple jobs by separating ids with a comma:

* `id:123`
* `id:123,124,125`

### Priority Filtering

The `priority` field is searchable as well. Use `priority:` and any combination
of values between `0` and `3` to filter jobs by priority:

* `priority:0`
* `priority:0,1`
* `priority:0,1,2,3`

### Quoted Terms

If your search query contains whitespace, you will need to surround it with
quotation marks. For example:

* `"foo bar"`
* `alpha not "foo bar"`

### Excluding Terms

You can exclude results containing a certain word, using the `not` syntax. The
`not` operator can only be used for `args`, `meta` and `tags`. It does not work
for `worker`.

* `not alpha`
* `foo -bar in:tags`

### Considerations

You can't use the following wildcard characters as part of your search query:

`, : ; / \ ' = * ! ? # $ & + ^ | ~ < > ( ) { } [ ]`

The search will stripe these symbols and ignore them.

## Performance

Full text queries may be prohibitively slow for large tables, especially for
states like `completed` that may have a lot of jobs. To boost full text query
performance you can add optional `gin` indexes for `args`, `meta`, or `tags`
columns:

```sql
-- Args
CREATE INDEX index_oban_jobs_gin_on_args
ON oban_jobs
USING gin (jsonb_to_tsvector('english', args, '["all"]'));

-- Meta
CREATE INDEX index_oban_jobs_gin_on_meta
ON oban_jobs
USING gin (jsonb_to_tsvector('english', meta, '["all"]'));

-- Tags
CREATE INDEX index_oban_jobs_gin_on_tags
ON oban_jobs
USING gin (array_to_tsvector(tags));
```

Remember, creating and maintaining indexes places additional burden on your
database. Before adding indexes, investigate using the focused search options
shown earlier in this guide.
