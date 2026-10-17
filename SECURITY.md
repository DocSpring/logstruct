# Security policy

## Reporting a vulnerability

Please report security issues privately through GitHub:
https://github.com/DocSpring/logstruct/security/advisories/new

Don't open a public issue or pull request for a vulnerability. Include the LogStruct version, your Rails and Ruby
versions, and the steps or configuration that show the problem. We'll reply in the advisory and work on a fix with you
there.

Examples of what we'd like to hear about: sensitive values that reach the logs despite the filters, log lines that an
attacker can drop or forge, and anything in LogStruct that lets a request crash or slow down the app.

## Supported versions

Security fixes go into the latest minor release. Please upgrade to it before reporting, if you can.

| Version | Supported |
| ------- | --------- |
| 0.1.x   | Yes       |
| < 0.1   | No        |
