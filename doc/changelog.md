# Changes

## v1.3.0 (2 April 2019)

- New: Drop support for ruby <2.3
- Fix: Build new strings instead of modifying frozen ones
- New: Add an accessor for the configured clean block
- New: Add a hook to use fabricated durations instead of actual timing data.

## v1.2.0 (5 July 2018)

- New: Use monotonic clock for duration calculations
- New: Drop support for ruby <2.1 to support monotonic clock
- New: Run CI on Ruby 2.5

## v1.1.2 (9 May 2018)

- New: Add `raise_with` option to allow for custom mismatch errors to be raised

## v1.1.1 (6 February 2018)

- Fix: default experiment no longer runs all `try` paths
- New: Add `Scientist.run` module method for running experiments when an included module isn't available
- New: Add [Noise and error rates](https://github.com/github/scientist#noise-and-error-rates) to `README.md`

## v1.1.0 (29 August 2017)

- New: [Specify which exception types to rescue](https://github.com/github/scientist#in-candidate-code)
- New: List [alternative implementations](https://github.com/github/scientist#alternatives) in `README.md`
- New: Code coverage via [coveralls.io](https://coveralls.io/github/github/scientist)
- New: Run CI on Ruby 2.3 and 2.4
- Fix: `README` typos, examples, and lies
- Fix: `false` results are now passed to the cleaner
