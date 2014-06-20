rabbitt-githooks
================

# GitHooks

Githooks provides a framework for creating standard pre-commit and commit-msg hooks for your git repository. These hooks run
client side (not on a remote server), and can be used to validate your commits (actual deltas and commit messages), reducing
the possibility of broken commits (or bad commit messages) making it into your repository.

## Installation

1. gem install rabbitt-githooks
2. add rabbitt-githooks to the development group of your project's Gemfile
2. setup your `project` to use githooks:

```
cd /path/to/project
mkdir commit-hooks
githooks attach --path /path/to/commit-hooks
```

With the hooks installed, you can run the checks against your staged or unstaged deltas before you commit, or just commit
your deltas and have the checks run automatically.

## Creating Tests

### Tests Path

All tests should be located under the path that was defined when attaching githooks to your project. In the following
examples we'll assume a project root of `/work/projects/railsapp` and a hooks path of `/work/projects/railsapp/.hooks`.

### Registration

All hooks must be registered via ```GitHooks::Hook.register <PHASE>, <BLOCK>```

### Commands
### Sections
### Actions
#### Limiters (aka filters)
#### on* (action executors)

<dl>
  <dt><strong>on_each_file(&block)</strong></dt>
  <dd></dd>
  <dt><strong>on_all_files(&block)</strong></dt>
  <dd></dd>
  <dt><strong>on_argv(&block)</strong></dt>
  <dd></dd>
</dl>

#### pre-commit vs commit-msg

## Command-Line Usage

### Listing Attached Tests
To view the list of checks currently attached to your repository:

```
$ cd /path/to/cms ; githooks list

Main Testing Library with Tests (in execution order):
  Tests loaded from:
    /Users/jdoe/work/repos/myproject/commit-hooks

  Phase PreCommit:
      1: Standards
        1: Validate Ruby Syntax
          Limiter 1: :type -> [:modified, :added]
          Limiter 2: :path -> /^(app|lib)\/.+\.rb$/
        2: No Leading Spaces in Ruby files
          Limiter 1: :type -> [:modified, :added]
          Limiter 2: :path -> /^(app|lib)\/.+\.rb$/
        3: Validate CSS Syntax
          Limiter 1: :type -> [:modified, :added]
          Limiter 2: :path -> /^(app|lib)\/.+css$/
  Phase CommitMsg:
      1: Commit Message
        1: Message Length > 5 characters
        2: Verify no simple commit messages
```

### Manually Running Tests

To run the pre-commit hook on unstaged deltas, run the following command:

```
$ cd /path/to/cms ; githooks exec --unstaged
===== PreCommit :: Standards =====
  1. [ X ] Validate Ruby Syntax
    X app/models/element.rb:245: syntax error, unexpected keyword_end, expecting end-of-input
  2. [ X ] No Leading Spaces in Ruby files
    X app/models/element.rb:4: _______# something here
    X app/models/element.rb:5: __a = 1
    X app/models/element.rb:6: ____
  3. [ X ] Validate CSS Syntax
    X app/assets/stylesheets/application.css.scss:4 [W] Prefer single quoted strings
    X app/assets/stylesheets/application.css.scss:8 [W] Use // comments everywhere
    X app/assets/stylesheets/application.css.scss:10 [W] Line should be indented 1 spaces, but was indented 2 spaces
    X app/assets/stylesheets/application.css.scss:19 [W] Each selector in a comma sequence should be on its own line
    X app/assets/stylesheets/application.css.scss:20 [W] Properties should be sorted in alphabetical order, with vendor-prefixed extensions before the standardized CSS property
    X app/assets/stylesheets/application.css.scss:22 [W] `0.75` should be written without a leading zero as `.75`
    X app/assets/stylesheets/application.css.scss:23 [W] `border: 0;` is preferred over `border: none;`
    X app/assets/stylesheets/elements.css.scss:35 [W] Commas in function arguments should be followed by a single space
    X app/assets/stylesheets/elements.css.scss:35 [W] Colon after property should be followed by 1 space instead of 0 spaces
    X app/assets/stylesheets/elements.css.scss:35 [W] Commas in function arguments should be followed by a single space

Commit failed due to errors listed above.
Please fix and attempt your commit again.
```

