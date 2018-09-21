(defpackage #:utopian/route
  (:use #:cl)
  (:import-from #:myway)
  (:export #:defroute
           #:render
           #:defroutes))
(in-package #:utopian/route)

(defvar *current-action*)

(defun render (&rest view-args)
  (if (and view-args
           (not (keywordp (first view-args))))
      (apply #'make-instance view-args)
      (apply #'make-instance *current-action* view-args)))

(defmacro defroute (name lambda-list &body body)
  (let ((params (gensym "PARAMS")))
    `(defun ,name ,(or lambda-list `(,params))
       ,@(unless lambda-list
           `((declare (ignore ,params))))
       (let ((*current-action* ',name))
         ,@body))))

(defvar *controllers-directory*)

(defun load-file (file)
  (let ((package-form
          (asdf/package-inferred-system::file-defpackage-form file)))
    (if package-form
        #+quicklisp
        (ql:quickload (second package-form))
        #-quicklisp
        (asdf:load-system (second package-form))
        (load file))))

(defun parse-controller-rule (rule)
  (etypecase rule
    (function rule)
    (string
     (destructuring-bind (controller-name action-name)
         (ppcre:split "::?" rule)
       (let ((file
               (make-pathname :name controller-name
                              :type "lisp"
                              :defaults *controllers-directory*)))
         (let ((package-name (second (asdf/package-inferred-system::file-defpackage-form file))))
           (unless package-name
             (error "File '~A' is not a package inferred system." file))
           #+quicklisp
           (ql:quickload package-name :silent t)
           #-quicklisp
           (asdf:load-system package-name)
           (let ((package (find-package package-name)))
             (unless package
               (error "No package '~A' in '~A'" package-name file))
             (let ((action (intern (string-upcase action-name) package)))
               (symbol-function action)))))))))

(defmacro defroutes (name routing-rules &rest options)
  (let ((*controllers-directory*
          (uiop:pathname-directory-pathname (or *load-pathname* *compile-file-pathname*))))
    (loop for option in options
          do (ecase (first option)
               (:directory
                (destructuring-bind (directory) (rest option)
                  (setf *controllers-directory*
                        (uiop:ensure-directory-pathname
                         (merge-pathnames directory *controllers-directory*)))))))
    `(progn
       (defvar ,name (myway:make-mapper))
       ;; TODO: clear rules
       ,@(loop for (method rule controller) in routing-rules
               collect `(myway:connect ,name ,rule (parse-controller-rule ,controller)
                                       :method ,method))
       ,name)))
