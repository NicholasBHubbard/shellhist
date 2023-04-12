# shellhist - history for M-x shell

shellhist is a package for saving the history of shell commands you enter into `M-x shell`. This history is global across all `M-x shell` buffers, and is saved across Emacs sessions. You can prevent commands from being added to the history through the use of filters in the `shellhist-filters` list.

# Functions

#### shellhist-history-search

Search your shell history with `completing-read`, and insert the selection into the `M-x shell` input buffer. It is recommended that you bind this function to a key in `shell-mode-map` (I personally bind it to `C-r`).

# Variables

#### shellhist-filters - defaults to `(list #'string-blank-p)`

A list of strings and functions that are used as filters to prevent inputs from entering the shell history.

Members of `shellhist-filters` that are strings are interpreted as regexs. If the regex matches the input command, then the command is not entered into the shell history.

Members of `shellhist-filters` that are functions should take a single argument representing input command. If the function returns a non-nil value when applied to the input command, then the command is not entered into the shell history.

#### shellhist-ltrim - defaults to `t`

If non-nil, then all whitespace (including newlines) is removed from the left side of the input command. Note that trimming takes place before the input command is passed through the filters in `shellhist-filters`.

#### shellhist-rtrim - defaults to `t`

If non-nil, then all whitespace (including newlines) is removed from the right side of the input command. Note that trimming takes place before the input command is passed through the filters in `shellhist-filters`.

#### shellhist-max-hist-size - defaults to 500

The maximum number of commands to keep in the shell history.

# Be Careful Of Completion Sorting

You almost certainly want the shell history sorted from most recent to oldest entries when browsing with `shellhist-history-search`. Your completion system may mess with this ordering, in which case you should wrap `shellhist-history-search` in a function that disables the sorting.

Here is an example function that disables sorting for `vertico`, `ivy`, `selectrum`, and `prescient`:

```elisp
(defun my/shellhist-history-search ()
  (interactive)
  (let ((ivy-sort-functions-alist nil)
        (ivy-prescient-enable-sorting nil)
        (vertico-sort-function nil)
        (vertico-sort-override-function nil)
        (vertico-prescient-enable-sorting nil)
        (selectrum-should-sort nil)
        (selectrum-prescient-enable-sorting t))
    (shellhist-history-search)))
```
