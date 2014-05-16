;;; cider-tests--no-auto.el --- Non-automated tests -*- lexical-binding: t -*-

;; Copyright © 2014 Jeff Valk

;; Author: Jeff Valk <jv@jeffvalk.com>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This file contains tests for CIDER that require an active nREPL connection
;; with `cider-nrepl' middleware, and can't currently be included in automated
;; CI builds.

;; To run these tests:
;;   All tests: M-x ert t
;;
;;; Code:

(require 'ert)
(require 'cider)
(require 'dash)
(require 'cl-lib)

;;; Docs
;; Presenting docs erroneously would cause an ugly scene.

(defun cider-test-doc (sym &optional dump)
  "Compare `cider-doc' output for SYM to the canonical `clojure.repl/doc'.
Prior to compare, Added/Deprecated info is removed from the former, and the
leading line of all dashes and trailing nil (when no doc is present) are removed
from the latter. Remaining content is compared for string equality."
  (let ((repl-doc (with-temp-buffer
                    (let ((form (format "(clojure.repl/doc %s)" sym)))
                      (insert (plist-get (nrepl-send-string-sync form) :stdout))
                      (goto-char (point-min))
                      (while (re-search-forward "^  nil\n" nil t)
                        (replace-match ""))
                      (goto-line 2)
                      (buffer-substring (point) (point-max)))))
        (cider-doc (-if-let (doc-buffer (cider-doc-buffer-for sym))
                       (with-current-buffer doc-buffer
                         (let ((inhibit-read-only t))
                           (goto-char (point-min))
                           (while (re-search-forward
                                   "^\\(Added\\|Deprecated\\).*\n" nil t)
                             (replace-match ""))
                           (prog1
                               (buffer-string)
                             (kill-buffer))))
                     "")))
    (when dump
      (message "== clojure.repl/doc ==\n%s" repl-doc)
      (message "== cider-doc ==\n%s" cider-doc))
    (string= cider-doc repl-doc)))

(defun cider-test-all-docs ()
  "Verify docs for all special forms and every public var in `clojure/core'."
  (let ((syms (cider-eval-and-get-value
               "(->> (merge @#'clojure.repl/special-doc-map
                     (->> (ns-map 'clojure.core)
                          (filter (every-pred
                                  (comp var? val)
                                  (complement (comp :private meta val))))))
                     (keys)
                     (remove '#{.}))"))) ; emacs lisp chokes on the dot symbol
    (let (untested diffs)
      (dolist (sym syms)
        (let ((name (cond ((symbolp sym) (symbol-name sym))
                          ((listp sym) (symbol-name (cadr sym))))))
          (if name
              (when (not (cider-test-doc name))
                (setq diffs (cons sym diffs)))
            (setq untested (cons sym untested)))))
      (when untested
        (message "Could not test: %s" untested))
      (when diffs
        (message "Mismatched: %s" diffs))
      (concatenate 'list untested diffs))))

(ert-deftest test-cider-cider-docs ()
  "Test all clojure doc output."
  (should (equal nil (cider-test-all-docs))))