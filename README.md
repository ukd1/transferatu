# Transferatu

[![Build Status](https://travis-ci.org/heroku/transferatu.svg?branch=master)](https://travis-ci.org/heroku/transferatu)

Transferatu moves your data from one place to another. As a service.

![Nosferatu](shadow.jpg "Nosferatu")

Currently supported transfer methods:

 * postgres -> postgres
 * postgres -> S3
 * S3 -> postgres

Transferatu is a [pliny](https://github.com/interagent/pliny) app.


## Setup

Transferatu is designed as a Heroku app:

```console
$ heroku create <your-app-name>
```

It needs a Heroku API token (to manage its workers) and AWS
credentials to access S3. The best way to create the API token is with
the [oauth plugin](https://github.com/heroku/heroku-oauth).

```console
$ heroku authorizations:create --description transferatu ----scope read-protected,write-protected
Created OAuth authorization.
  ID:          105a7bfa-34c3-476e-873a-b1ac3fdc12fb
  Description: transferatu
  Token:       <your-token>
  Scope:       read-protected,write-protected
```

[Create an S3 bucket](http://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html) and then
[create an AWS user](http://docs.aws.amazon.com/IAM/latest/UserGuide/Using_SettingUpUser.html#Using_CreateUser_console)
with an access policy restricted to read and write that bucket and
its contents:

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::<your-transferatu-bucket>",
        "arn:aws:s3:::<your-transferatu-bucket>/*"
      ]
    }
  ]
}
```

Set the config vars related to these, as well as the app name
(Transferatu needs to know this for run process management),
and bucket name:

```console
$ heroku config:set HEROKU_API_TOKEN=<your-token> \
  HEROKU_APP_NAME=<your-app-name> \
  AWS_ACCESS_KEY_ID=<your-role-id> \
  AWS_SECRET_ACCESS_KEY=<your-role-key> \
  S3_BUCKET_NAME=<your-transferatu-bucket> \
  AT_REST_FERNET_SECRET=`ruby -e 'require "securerandom";puts SecureRandom.urlsafe_base64(32)'`
Setting config vars and restarting <your-app-name>... done, v56
```

Transferatu also needs a Postgres database:

```console
$ heroku addons:add heroku-postgresql:premium-yanari
```

Once everything is set up, you can deploy, run a schema migration to
set up the database, and scale up the clock process:

```console
$ git push heroku master
...
$ heroku run bundle exec rake db:migrate
$ heroku ps:scale clock=1
```


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
