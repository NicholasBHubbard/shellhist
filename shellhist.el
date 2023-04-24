;;; shellhist.el --- Keep track of shell history  -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Nicholas Hubbard <nicholashubbard@posteo.net>
;;
;; Licensed under the same terms as Emacs and under the MIT license.

;; SPDX-License-Identifier: MIT

;; Author: Nicholas Hubbard <nicholashubbard@posteo.net>
;; URL: https://github.com/NicholasBHubbard/shellhist
;; Package-Requires: ((emacs "25.1"))
;; Version: 1.0
;; Created: 2023-02-22
;; By: Nicholas Hubbard <nicholashubbard@posteo.net>
;; Keywords: convenience

;;; Commentary:

;; This package provides functionality for saving the input history in M-x shell
;; in a configurable manner.

;; To start saving the shell history, the minor-mode `shellhist-mode' must be
;; turned on.

;; By default, all M-x shell input is added into the `shellhist--history'
;; (excluding blank entries), however the user can add filters to
;; `shellhist-filters' that prevent items from entering the history.  Filters can
;; either be strings or functions.  String filters are interpreted as regexs such
;; that if the input matches the regex then it is not added to the history.
;; Function filters are functions that should take the input as an argument such
;; that if the function returns a non-nil value then the input is not added to
;; the history.  Duplicate items are automatically removed from the history (by
;; removing the old duplicate and keeping the new one).  The input history is
;; saved to a file so it can persist across Emacs sessions.

;; It is important to note that the `shellhist--history' is global (as opposed
;; to buffer-local).  This means that all M-x shell buffers share their history.

;; The interactive function `shellhist-history-search' is provided for selecting
;; a history item with `completing-read', and inserting it into the M-x shell
;; input area.  It is recommended to bind this function to some key in
;; `shell-mode-map'.

;;; Code:

(require 'comint)
(require 'subr-x)

(defvar shellhist--history nil
  "The shellhist history list.")

(defvar shellhist--history-loaded-p nil
  "T if the shellhist has already been loaded from disk.")

(defvar shellhist-max-hist-size 500
  "Maximum number of history elements.")

(defvar shellhist-ltrim t
  "T if whitespace should be trimmed from left side of input before processing.")

(defvar shellhist-rtrim t
  "T if whitespace should be trimmed from right side of input before processing.")

(defvar shellhist-filters (list #'string-blank-p)
  "List of filters for preventing entries into `shellhist--history'.

These filters can be strings or functions.  If a filter is a string then it is
interpreted as a regexp, and will filter input that matches the regexp.  If a
filter is a function then it will filter input that when applied to it, returns
a non-nil value.")

(defun shellhist--process-input (&rest _)
  ":before advice to `comint-sent-input' when `shellhist-mode' is enabled.

This function adds the input that is about to be sent to the shell to
`shellhist--history', as long as it is not caught by one of the filters in
`shellhist-filters'."
  (if (eq major-mode 'shell-mode)
      (let ((proc (get-buffer-process (current-buffer))))
        (if (not proc) (user-error "Current buffer has no process")
          (widen)
          (let* ((pmark (process-mark proc))
                 (input-raw (if (>= (point) (marker-position pmark))
                                (progn (if comint-eol-on-send
                                           (if comint-use-prompt-regexp
                                               (end-of-line)
                                             (goto-char (field-end))))
                                       (buffer-substring pmark (point)))
                              (let ((copy (funcall comint-get-old-input)))
                                (goto-char pmark)
                                (insert copy)
                                copy)))
                 (input-raw (if shellhist-ltrim
                                (replace-regexp-in-string "^[\n ]+" "" input-raw)
                              input-raw))
                 (input-raw (if shellhist-rtrim
                                (replace-regexp-in-string "[\n ]+$" "" input-raw)
                              input-raw))
                 (input input-raw)
                 (ok t))
            (catch 'loop
              (dolist (filter shellhist-filters)
                (if (stringp filter) ; regexp
                    (when (string-match-p filter input)
                      (setq ok nil)
                      (throw 'loop t))
                  (when (funcall filter input) ; function
                    (setq ok nil)
                    (throw 'loop t)))))
            (when ok
              (delete-dups (push input shellhist--history))
              (let ((len (length shellhist--history)))
                (if (> len shellhist-max-hist-size)
                    (nbutlast shellhist--history (- len shellhist-max-hist-size))))))))))

(defun shellhist-history-search ()
  "Search `shellhist--history' with `completing-read' and insert the selection.

If any input already exists in the shell input buffer, then it is deleted
before inserting the selected value."
  (interactive)
  (let ((history-val (completing-read "Shell History: " shellhist--history)))
    (goto-char (point-max))
    (delete-region (line-beginning-position) (line-end-position))
    (insert history-val)))

(defun shellhist--load-save-file ()
  "Return the contents of .shellhist-history as a list."
  (let ((file (expand-file-name ".shellhist-history" user-emacs-directory)))
    (if (file-readable-p file)
        (with-temp-buffer
          (insert-file-contents-literally file)
          (split-string (buffer-string) "\n" t)))))

(defun shellhist--save ()
  "Write `shellhist--history' to disk."
  (let ((file (expand-file-name ".shellhist-history" user-emacs-directory))
        (to-save
         (seq-take
          (delete-dups
           (append shellhist--history (shellhist--load-save-file)))
          shellhist-max-hist-size)))
    (with-temp-buffer
      (dolist (v to-save)
        (insert v "\n")
        (forward-line 1))
      (write-region (point-min) (point-max) file))))

(define-minor-mode shellhist-mode
  "Toggle `shellhist-mode'."
  :require 'shellhist
  (if shellhist-mode
      (progn
        (unless shellhist--history-loaded-p
          (setq shellhist--history (shellhist--load-save-file))
          (setq shellhist--history-loaded-p t))
        (advice-add 'comint-send-input :before #'shellhist--process-input)
        (add-hook 'kill-emacs-hook #'shellhist--save))
    (advice-remove 'comint-send-input #'shellhist--process-input)
    (remove-hook 'kill-emacs-hook #'shellhist--save)))

(provide 'shellhist)

;; Local Variables:
;; indent-tabs-mode: nil
;; End:
;;; shellhist.el ends here
