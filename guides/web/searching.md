# Searching Jobs

The search bar supports basic and advanced syntax to whittle down jobs based on
multiple fields. Without any qualifiers, your terms are matched against
`worker`, `tags`, `args` and `meta` fields using loose matching or `tsquery`
checks, as appropriate.

For more advanced syntax, check the sections below.

_Note: Multi-field advanced searching is only supported for PostgreSQL 11+. For
older versions, only the `worker` is searched_

## Qualifier Syntax

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

## Nested Syntax

For the `jsonb` fields, `args` and `meta`, you can also use "dot" path syntax to
restrict search to nested data.

* `a1b2c3d4 in:meta.worker_id`
* `business in:args.user.plan.name`

Naturally, you can combine path syntax with multi-field syntax:

* `foo in:args.batch_id,meta.worker_id`
* `foo in:args.user.plan,tags`

## Quoted Terms

If your search query contains whitespace, you will need to surround it with
quotation marks. For example:

* `"foo bar"`
* `alpha not "foo bar"`

## Exclude Syntax

You can exclude results containing a certain word, using the `not` syntax. The
`not` operator can only be used for `args`, `meta` and `tags`. It does not work
for `worker`.

* `not alpha`
* `foo -bar in:tags`

## Priority Search

The `priority` field is searchable as well. Use `priority:` and any combination
of values between `0` and `3` to filter jobs by priority:

`priority:0`
`priority:0,1`
`priority:0,1,2,3`

## Considerations

You can't use the following wildcard characters as part of your search query:

`, : ; / \ ' = * ! ? # $ & + ^ | ~ < > ( ) { } [ ]`

The search will stripe these symbols and ignore them.

## Advanced Examples

Here are a few examples that combine the available syntax and demonstrate what's
possible:

* `alpha in:worker`
* `alpha -omega in:tags,meta`
* `alpha not omega in:tags priority:0`
* `alpha not "super alpha" in:tags pro in:args.account.plan`
