# Search Syntax

## Qualifier Syntax

With the in qualifier you can restrict your search to the title, body, comments, or any
combination of these. When you omit this qualifier, the title, body, and comments are all
searched.

`in:worker`
`in:tags`
`in:args`
`in:meta` `in:tags,meta,args`
`in:queue`

## Nested Syntax

`in:meta.worker_id`
`in:args.user.plan.name`

## Numerical Syntax

`priority:0`
`priority:0,1`

## Date Syntax

`scheduled_at:>2021-04-26`
`scheduled_at:<2021-04-26`

## Exclude Syntax

You can exclude results containing a certain word, using the NOT syntax. The NOT operator can only
be used for string keywords. It does not work for numerals or dates.

`term not in:worker`

Another way you can narrow down search results is to exclude certain subsets. You can prefix any
search qualifier with a - to exclude all results that are matched by that qualifier.

`foo -bar in:worker`

## Quoted

If your search query contains whitespace, you will need to surround it with
quotation marks. For example:

    cats NOT "hello world" matches repositories with the word "cats" but not the words "hello world."
    build label:"bug fix" matches issues with the word "build" that have the label "bug fix."

Some non-alphanumeric symbols, such as spaces, are dropped from code search
queries within quotation marks, so results can be unexpected.

## Considerations

You can't use the following wildcard characters as part of your search query:
`. , : ; / \ ' " = * ! ? # $ & + ^ | ~ < > ( ) { } [ ]`.

The search will simply ignore these symbols.

## Example Playground

alpha in:worker
alpha NOT omega in:tags,meta
alpha NOT omega in:tags priority:0
alpha NOT "super alpha" in:tags pro in:args.account.plan scheduled:>2021-04-25
