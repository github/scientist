# Changes

## v1.6.5 (16 December 2024)

- New: measure CPU time alongside wall time for experiments #275

## v1.6.4 (5 April 2023)

- New: GitHub Actions for CI #171
- New: add ruby 3.1 support #175
- Fix: `compare_errors` in docs #178
- Fix: remove outdated travis configs #179
- Fix: typos #191
- New: add support for `after_run` blocks #211

## v1.6.3 (9 December 2021)

- Fix: improve marshaling implementation #169

## v1.6.2 (4 November 2021)

- New: make `MismatchError` marshalable #168

## v1.6.1 (22 October 2021)

- Fix: moving supported ruby versions from <=2.3 to >=2.6 #150
- Fix: update docs to explain timeout handling #159
- New: add support for comparing errors #77

## v1.6.0 (8 March 2021)

- Fix: clarify unit for observations #124
- New: enable support for truffleruby #143
- Fix: don't default experiment when included in a module #144

## v1.5.0 (8 September 2020)

- Fix: clearer explanation of exception handling #110
- Fix: remove unused attribute from `Scientist::Observation` #119
- New: Added internal extension point for generating experinet results #121
- New: Add `Scientist::Experiment.register` helper #104

## v1.4.0 (20 September 2019)

- New: Make `MismatchError` a base `Exception` #107

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
