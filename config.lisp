(in-package #:cl-user)
(defpackage utopian/config
  (:use #:cl)
  (:import-from #:utopian/app
                #:project-path)
  (:export #:*default-app-env*
           #:environment-config
           #:config
           #:appenv
           #:developmentp
           #:productionp))
(in-package #:utopian/config)

(defvar *config-cache*
  (make-hash-table :test 'equal))

(defvar *default-app-env* "development")

(defun environment-config (env)
  (let ((file (make-pathname :name env
                             :type "lisp"
                             :defaults (project-path #P"config/environments/"))))
    (when (probe-file file)
      (let ((modified-at (file-write-date file)))
        (cond
          ((< (car (gethash file *config-cache* '(0 . nil)))
              modified-at)
           (let ((config (uiop:with-safe-io-syntax ()
                           (with-open-file (in file)
                             (uiop:eval-input in)))))
             (setf (gethash file *config-cache*)
                   (cons modified-at config))
             config))
          (t
           (cdr (gethash file *config-cache*))))))))

(defun config (&optional key)
  (let ((config (environment-config
                 (or (uiop:getenv "APP_ENV") *default-app-env*))))
    (if key
        (getf config key)
        config)))

(defun appenv ()
  (uiop:getenv "APP_ENV"))

(defun (setf appenv) (env)
  (setf (uiop:getenv "APP_ENV") env))

(defun developmentp ()
  (string= (appenv) "development"))

(defun productionp ()
  (find (appenv) '("production" "staging") :test #'string=))
