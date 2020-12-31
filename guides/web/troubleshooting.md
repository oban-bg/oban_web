# Troubleshooting

### Authorizing with Heroku or Gigalixir

If your app runs on Heroku using the [Elixir Buildpack][ebp] (rather than Docker) you'll need to use compilation hook to authorize hex before fetching dependencies.

First, if you haven't already, set your license key on Heroku:

```bash
heroku config:set OBAN_WEB_LICENSE_KEY="YOUR OBAN WEB LICENSE KEY"
```

Next, add a small shell script to your application in `./bin/predeps`:

```bash
#!/bin/bash

mix hex.organization auth oban --key "$OBAN_WEB_LICENSE_KEY"
```

Finally, set the `predeps` script within `elixir_buildpack.config`:

```
hook_pre_fetch_dependencies="./bin/predeps"
```

Thanks to [Jessie Cooke][jc] for the [solution to this situation][sol]!

[ebp]: https://github.com/HashNuke/heroku-buildpack-elixir
[jc]: https://github.com/jc00ke
[sol]: https://jc00ke.com/2019/10/28/hex-auth-key-elixir-buildpack-heroku/
