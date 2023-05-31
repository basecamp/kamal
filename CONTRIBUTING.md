# Contributing to MRSK development

Thank you for considering contributing to MRSK! This document outlines some guidelines for contributing to this open source project.

Please make sure to review our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing to MRSK.

There are several ways you can contribute to the betterment of the project:

- **Report an issue?** - If the issue isn’t reported, we can’t fix it. Please report any bugs, feature, and/or improvement requests on the [MRSK GitHub Issues tracker](https://github.com/mrsked/mrsk/issues).
- **Submit patches** - Do you have a new feature or a fix you'd like to share? [Submit a pull request](https://github.com/mrsked/mrsk/pulls)!
- **Write blog articles** - Are you using MRSK? We'd love to hear how you're using it with your projects. Write a tutorial and post it on your blog!

## Issues

If you encounter any issues with the project, please check the [existing issues](https://github.com/mrsked/mrsk/issues) first to see if the issue has already been reported. If the issue hasn't been reported, please open a new issue with a clear description of the problem and steps to reproduce it.

## Pull Requests

Please keep the following guidelines in mind when opening a pull request:

- Ensure that your code passes the project's minitests by running ./bin/test.
- Provide a clear and detailed description of your changes.
- Keep your changes focused on a single concern.
- Write clean and readable code that follows the project's code style.
- Use descriptive variable and function names.
- Write clear and concise commit messages.
- Add tests for your changes, if possible.
- Ensure that your changes don't break existing functionality.

#### Commit message guidelines

A good commit message should describe what changed and why.

## Development

The `main` branch is regularly built and tested, but it is not guaranteed to be completely stable. Tags are created regularly from release branches to indicate new official, stable release versions of MRSK.

MRSK is written in Ruby. You should have Ruby 3.2+ installed on your machine in order to work on MRSK. If that's already setup, run `bundle` in the root directory to install all dependencies. Then you can run `bin/test` to run all tests.

1. Fork the project repository.
2. Create a new branch for your contribution.
3. Write your code or make the desired changes.
4. **Ensure that your code passes the project's minitests by running ./bin/test.**
5. Commit your changes and push them to your forked repository.
6. [Open a pull request](https://github.com/mrsked/mrsk/pulls) to the main project repository with a detailed description of your changes.

## License

MRSK is released under the MIT License. By contributing to this project, you agree to license your contributions under the same license.
