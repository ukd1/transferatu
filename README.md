# Transferatu

[![Build Status](https://travis-ci.org/heroku/transferatu.svg?branch=master)](https://travis-ci.org/heroku/transferatu)

Transferatu moves your data from one place to another. As a service.

![Nosferatu](shadow.jpg "Nosferatu")

Currently supported transfer methods:

 * postgres -> postgres
 * postgres -> S3
 * S3 -> postgres

## Quiescence

Occasionally, you may want to have your backup workers take a breather
and pause transfer processing (e.g., when performing maintenance on
the app). To this end, Transferatu includes a mechanism to stop
accepting new jobs:

```term
$ heroku run bundle exec rake quiescence:enable
```

You can optionally cancel any in-progress transfers as well:

```term
$ heroku run bundle exec rake quiescence:enable[hard]
```

To restore normal operation, disable quiescence:

```term
$ heroku run bundle exec rake quiescence:disable
```

Note also that Transferatu workers are designed to run as standalone
`heroku run` processes. This makes it possible to deploy changes
without interrupting in-progress transfers. However, it does mean that
workers can end up running out-of-date code. To work around this,
workers are automatically soft-quiesced (and, naturally, restarted)
after every code push.
