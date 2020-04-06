# ObanWeb

A live dashboard for monitoring and operating Oban.

## Installation (For Development)

Using ObanWeb from another application in development mode requires a little
maneuvering. While you can specify `oban_web` as a path dependency, that doesn't
work with Phoenix's code reloading features. During development I suggest the
following work-flow:

Switching to Development

1. In `mix.exs` comment out `oban_web`
2. Create symlinks from `oban_web` into the `lib` directory of your primary app

I recommend automating the steps with a make task, as this is something you'll
do often. This command will automate linking local `oban_web`:

```make
relink-oban-web:
	sed -i '' '/:oban_web/ s/\(.*\)\({.*\)/\1# \2/' mix.exs && \
	cd lib && \
	ln -fs ../../oban_web/lib/oban_web ./oban_web && \
	ln -fs ../../oban_web/lib/oban_web.ex ./oban_web.ex
```

And this command to switch back to the published version:

```make
unlink-oban-web:
	sed -i '' '/:oban_web/ s/\(.*\)# \(.*\)/\1\2/' mix.exs && \
	rm lib/oban_web* && \
	mix deps.update oban_web
```

## Installation (From a Package)

See the official installation docs at [https://oban.dev/docs/installation][].

[plv]: https://github.com/phoenixframework/phoenix_live_view#installation
[hpm]: https://hex.pm/docs/private#authenticating-on-ci-and-build-servers

## Contributing

Working on ObanWeb has the following dependencies:

1. Elixir 1.8+
2. Erlang/OTP 21.0+
3. Postgres 10+
4. Node (for [parcel](https://parceljs.org/))
5. Brew (for fswatch and [sassc](https://github.com/sass/sassc))

We'll assume you have Elixir/Erlang/PostgreSQL running already (because you
wouldn't be reading this otherwise!). To install the remaining dependencies run
`make prepare`. That will install `fswatch`, `sassc`, `parcel` and fetch `mix
deps`

#### Update Assets

Run `make watch` when you need to change js or css assets. That will take care
of:

1. `make js` to bundle the latest phoenix and live view js
2. `make css` to compile scss
3. `make watch_loop` to start the css compilation loop

The compilation loop ensures that the css assets are compiled and stay up
to date. The js asset(s) are only compiled once, when the loop starts. These
don't change very often and are much slower to build.

#### Tests & Code Quality

To ensure a commit passes CI you should run `MIX_ENV=test mix ci` locally, which
executes the following commands:

* Check formatting (`mix format --check-formatted`)
* Lint with Credo (`mix credo --strict`)
* Run all tests (`mix test --raise`)
