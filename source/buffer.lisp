;;; buffer.lisp --- lisp subroutines for creating / managing buffers

(in-package :next)

(define-parenstatic buffer-get-url
    (ps:chain window location href))

(define-parenscript buffer-set-url (url)
  ((setf (ps:chain this document location href) (ps:lisp url))))

(defmethod object-string ((buffer buffer))
  (name buffer))

(define-command make-buffer ()
  "Create a new buffer."
  (let ((buffer (buffer-make *interface*)))
    (setf (name buffer) "default")
    (setf (mode buffer) (document-mode))
    buffer))

(defun buffer-completion-generator ()
  (let ((buffers (alexandria:hash-table-values (buffers *interface*))))
    (lambda (input)
      (fuzzy-match input buffers #'name))))

(define-command switch-buffer ()
  "Switch the active buffer in the current window."
  (with-result (buffer (read-from-minibuffer
                        *minibuffer*
                        :input-prompt "Switch to buffer:"
                        :completion-function (buffer-completion-generator)))
    (set-active-buffer *interface* buffer)))

(define-command make-visible-new-buffer ()
  "Make a new empty buffer with the *default-new-buffer-url* loaded"
  (let ((new-buffer (make-buffer)))
    (set-active-buffer *interface* new-buffer)
    (buffer-evaluate-javascript *interface*
                                new-buffer
                                (buffer-set-url *default-new-buffer-url*))))

(define-command delete-buffer ()
  "Delete the buffer via minibuffer input."
  (with-result (buffer (read-from-minibuffer
                        *minibuffer*
                        :input-prompt "Kill buffer:"
                        :completion-function (buffer-completion-generator)))
    (%delete-buffer buffer)))

(defmethod %delete-buffer ((buffer buffer))
  (when (equal (active-buffer *interface*) buffer)
    (make-visible-new-buffer))
  (buffer-delete *interface* buffer))

(defmethod add-mode ((buffer buffer) mode &optional (overwrite nil))
  (let ((found-mode (gethash (class-name (class-of mode)) (modes buffer))))
    (when (or (not found-mode) (and found-mode overwrite))
      (setf (buffer mode) buffer)
      (setf (gethash (class-name (class-of mode)) (modes buffer)) mode))))

(defmethod switch-mode ((buffer buffer) mode)
  (let ((found-mode (gethash (class-name (class-of mode)) (modes buffer))))
    (when found-mode
      (setf (mode buffer) found-mode))))

(defmethod add-or-switch-to-mode ((buffer buffer) mode)
  (add-mode buffer mode)
  (switch-mode buffer mode))

(defun generate-new-buffer (name mode)
  (let ((new-buffer
	 (make-instance 'buffer
			:name name
			:mode mode
			:modes (make-hash-table :test 'equalp)
			:view (buffer-make *interface*))))
    (push new-buffer *buffers*)
    (setup mode new-buffer)
    (setf (gethash (class-name (class-of (mode new-buffer))) (modes new-buffer)) (mode new-buffer))
    new-buffer))

(defun set-visible-active-buffer (buffer)
  (set-active-buffer buffer)
  (window-set-active-buffer *interface*
                            (view *active-buffer*)
                            (window-active *interface*)))


(defun get-active-buffer-index ()
  (position *active-buffer* *buffers* :test #'equalp))

(define-command switch-buffer-previous ()
  "Switch to the previous buffer in the list of *buffers*, if the
first item in the list, jump to the last item."
  (let ((active-buffer-index (position *active-buffer* *buffers* :test #'equalp)))
    (if (equalp 0 active-buffer-index)
	(set-visible-active-buffer (nth (- (length *buffers*) 1) *buffers*))
	(set-visible-active-buffer (nth (- active-buffer-index 1) *buffers*)))))

(define-command switch-buffer-next ()
  "Switch to the next buffer in the list of *buffers*, if the last
item in the list, jump to the first item."
  (let ((active-buffer-index (position *active-buffer* *buffers* :test #'equalp)))
    (if (< (+ active-buffer-index 1) (length *buffers*))
        (set-visible-active-buffer (nth (+ active-buffer-index 1) *buffers*))
        (set-visible-active-buffer (nth 0 *buffers*)))))

(define-command delete-active-buffer ()
  "Delete the currently active buffer, and make the next buffer
*buffers* the visible buffer. If no other buffers exist, set the url
of the current buffer to the start page."
  (if (> (length *buffers*) 1)
      (let ((former-active-buffer *active-buffer*))
        ;; switch-buffer-next changes value of *active-buffer*
        ;; which in turn changes the value of former-active-buffer
        (switch-buffer-next)
        ;; therefore delete actually deletes the new *active-buffer*
        (%delete-buffer former-active-buffer))
      (set-url *start-page-url*)))

