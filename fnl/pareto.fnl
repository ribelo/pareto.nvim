(local api vim.api)

(local ts-utils (require :nvim-treesitter.ts_utils))
(local ts-query (require :vim.treesitter.query))

(fn replace-termcodes [s]
  (api.nvim_replace_termcodes s true true true))

(fn feedkeys [s mode escape-ks]
  (api.nvim_feedkeys s (or mode :n) (or escape-ks false)))

(fn get-buf-line-count [buf-id]
  (api.nvim_buf_line_count (or buf-id 0)))

(fn get-buf-lines [buf-id row-start row-end]
  (api.nvim_buf_get_lines 
    (or buf-id 0) 
    (or row-start 0) 
    (or row-end (get-buf-line-count buf-id))
    true))

(fn get-line-length [buf-id row]
  (length (. (get-buf-lines (or buf-id 0) row (+ row 1)) 1)))

(fn get-buf-text [buf-id row-start col-start row-end col-end]
  (api.nvim_buf_get_text 
    (or buf-id 0)
    (or row-start 0)
    (or col-start 0)
    (or row-end (get-buf-line-count buf-id))
    (or col-end
        (let [n (get-buf-line-count)] 
          (print row-end n)
          (-> (get-buf-lines 0 (or row-end n) (+ (or row-end n) 1)) (. 1) (length))))
    {}))

(fn get-cursor [winnr]
  (let [[row col] (api.nvim_win_get_cursor (or winnr 0))]
    (values row col)))

(fn get-cursor-range [winnr]
  (let [(row col) (get-cursor winnr)]
    (values (- row 1) (- col 1))))

(fn get-mode []
  (api.nvim_get_mode))

(fn get-char-at [buf-id row col]
  (. (get-buf-text (or buf-id 0) row col row (+ col 1)) 1))

(fn get-char-at-cursor []
  (get-char-at 0 (get-cursor-range)))

(fn get-left-char []
  (let [(row col) (get-cursor-range)]
   (print :row row :col col)
    (if (> col 0) 
      (match (get-mode)
        {:mode :n} ( . ( api.nvim_buf_get_text 0 row (+ col 1) row (+ col 2) {}) 1)
        {:mode :i} ( . ( api.nvim_buf_get_text 0 row col row (+ col 1) {}) 1)))))

(fn get-right-char []
  (let [(row col) (get-cursor-range)]
    (match (get-mode)
     {:mode :n} ( . ( api.nvim_buf_get_text 0 row (+ col 1) row (+ col 2) {}) 1)
     {:mode :i} ( . ( api.nvim_buf_get_text 0 row (+ col 1) row (+ col 2) {}) 1))))

(local parens-map 
  {"(" ")"
   ")" "("
   "[" "]"
   "]" "["
   "{" "}"
   "}" "{"})

(fn get-pair [x]
  (. parens-map x))

(fn match-paren? [x y]
  (= y (. parens-map x)))

(fn opening-paren? [x]  
  (vim.tbl_contains ["(" "{" "[" "<"] x))

(fn closing-paren? [x]  
  (vim.tbl_contains [")" "}" "]" ">"] x))

(fn set-text [buf start-row start-col end-row end-col xs]
  (let [buf (or buf (api.nvim_get_current_buf))] 
    (api.nvim_buf_set_text buf start-row start-col end-row end-col xs)))

(fn set-cursor [x y]
  (if (and (>= x 0) (>= y 0)) 
    (api.nvim_win_set_cursor 0 [x y])))

(fn move-cursor-by [x y]
  (let [(row col) (get-cursor-range)]
    ;; (1 0) indexed
    (set-cursor (+ (+ 1 row) x) (+ (+ col 1) y))))

(fn set-text-at-cursor [buf xs]
  (let [(row col) (get-cursor-range)]
    (match (api.nvim_get_mode)
     {:mode :n} (set-text buf row col row col xs)
     {:mode :i} (set-text buf row (+ col 1) row (+ col 1) xs))))

(fn insert-text-at-cursor [buf xs]
  (set-text-at-cursor buf xs)
  (move-cursor-by 0 (length xs)))

(fn delete-text-before-cursor [buf]
  (let [(row col) (get-cursor-range 0)]
    (set-text 0 row (- col 1) row col [])
    (move-cursor-by 0 -1)
    ))

(fn delete-text-after-cursor [buf]
  (let [(row col) (get-cursor-range 0)
        lines-count (get-buf-line-count (or buf 0))
        line-length (get-line-length (or buf 0) row)]
    (if (< (+ col 1) line-length) 
      (set-text (or buf 0) row (+ col 1) row (+ col 2) [])
      (if (< (+ row 1) lines-count)
        (set-text (or buf 0) row (+ col 1) (+ row 1) 0 [])))))

(fn node-text [node]
  (let [node (or node (ts-utils.get_node_at_cursor))]
    (ts-query.get_node_text node 0)))

(local fennel (require :fennel))

(fn copy [fallback]
  (let [buf (api.nvim_get_current_buf)]
    (if (opening-paren? (get-right-char))
      (let [node (ts-utils.get_node_at_cursor)
            node-text (ts-query.get_node_text node buf)
            (start-row start-col end-row end-col) (-> (ts-utils.get_node_at_cursor) (ts-utils.get_node_range))] 
        (set-text buf end-row end-col end-row end-col node-text))
      (closing-paren? (get-left-char))
      (let [_ (move-cursor-by 0 -1)
            (row col) (get-cursor-range)
            node (-> (ts-utils.get_node_at_cursor))
            node-text (ts-query.get_node_text node buf)
            (start-row start-col end-row end-col) (-> (ts-utils.get_node_at_cursor) (ts-utils.get_node_range))] 
        (set-text buf end-row end-col end-row end-col [node-text])
        (set-cursor (+ row 1) (+ col 2)))
      (insert-text-at-cursor buf [fallback]))))

(fn diffrent [fallback]
  (let [buf (api.nvim_get_current_buf)]
    (if (opening-paren? (get-right-char))
      (let [node (ts-utils.get_node_at_cursor)] 
        (ts-utils.goto_node node true)
        (move-cursor-by 0 1))
      (closing-paren? (get-left-char))
      (let [_ (move-cursor-by 0 -1)
            node (ts-utils.get_node_at_cursor)] 
        (ts-utils.goto_node node false))
      (insert-text-at-cursor buf [fallback]))))

(fn find-next-char [buf row col find-xs break-xs]
  (let [buf (or buf 0)]
    (if (<= row (get-buf-line-count buf))
      (let [line-length (get-line-length buf row)]
        (if (<= col line-length)
          (let [char (get-char-at buf row col)]
            (if (or (and (= "table" (type find-xs)) (vim.tbl_contains find-xs char))
                    (and (= "string" (type find-xs)) (= find-xs char)))
              (values row col)
              (and (not (and (= "table" (type break-xs)) (vim.tbl_contains break-xs char)))
                   (not (and (= "string" (type break-xs)) (= break-xs char))))
              (find-next-char buf row (+ col 1) find-xs break-xs)))
          (find-next-char buf (+ row 1) 1 find-xs break-xs))))))

(fn find-prev-char [buf row col find-xs break-xs]
  (let [buf (or buf 0)
        col (or col (get-line-length buf row))]
    (if (> row 0)
      (let [line-length (get-line-length buf row)]
        (if (> col 0)
          (let [char (get-char-at buf row col)]
            (if (or (and (= "table" (type find-xs)) (vim.tbl_contains find-xs char))
                    (and (= "string" (type find-xs)) (= find-xs char)))
              (values row col)
              (and (not (and (= "table" (type break-xs)) (vim.tbl_contains break-xs char)))
                   (not (and (= "string" (type break-xs)) (= break-xs char))))
              (find-prev-char buf row (- col 1) find-xs break-xs)))
          (find-prev-char buf (- row 1) nil find-xs break-xs))))))

(fn step-inside [fallback]
  (let [buf (api.nvim_get_current_buf)
        (row col) (get-cursor 0)]
    (if (opening-paren? (get-right-char))
      (let [(x y) (find-next-char buf (- row 1) (+ col 2) ["(" "[" "{"] [")" "]" "}"])]
        (when (and x y) 
          (set-cursor (+ x 1) y)))
      (closing-paren? (get-left-char))
      (let [(x y) (find-prev-char buf row (- col 1) [")" "]" "}"] ["(" "[" "{"])] ; }])
      (if (and x y) 
        (set-cursor (+ x 1) y)))
    (insert-text-at-cursor buf [fallback]))))

(fn delete [fallback]
  (let [buf (api.nvim_get_current_buf)
        (row col) (get-cursor 0)
        char (get-right-char)]
    (if (or (opening-paren? char)
            (= "\"" char)
            (= "\'" char))
      (let [node (ts-utils.get_node_at_cursor)
            node-text (ts-query.get_node_text node buf)
            (start-row start-col end-row end-col) (-> node (ts-utils.get_node_range))] 
        (set-text buf start-row start-col end-row end-col []))  
      (delete-text-after-cursor buf))))

(fn mark-block [sr sc er ec goto]
  (match goto 
    (where (or :end nil)) 
    (do (set-cursor sr sc)
        (vim.cmd (.. "normal! " (replace-termcodes "v")))
        (set-cursor er ec)
        true)
    :start
    (do (set-cursor er ec) 
        (vim.cmd (.. "normal! " (replace-termcodes "v")))
        (set-cursor sr sc)
        true)
    _ false))

(fn mark [fallback]
  (let [buf (api.nvim_get_current_buf)
        (row col) (get-cursor 0)]
    (if (opening-paren? (get-right-char))
      (let [node (ts-utils.get_node_at_cursor)
            (start-row start-col end-row end-col) (-> node (ts-utils.get_node_range))] 
        (mark-block (+ start-row 1) start-col (+ end-row 1) end-col :end)
        (feedkeys (replace-termcodes "<esc>")))

      (closing-paren? (get-left-char))
      (let [_ (move-cursor-by 0 -1)
            node (ts-utils.get_node_at_cursor)
            (start-row start-col end-row end-col) (-> node (ts-utils.get_node_range))] 
        (mark-block (+ start-row 1) (+ start-col 1) (+ end-row 1) (- end-col 1) :start)
        (feedkeys (replace-termcodes "<esc>")))

      (insert-text-at-cursor buf [fallback]))))

(fn comment-node [fallback]
  (let [buf (api.nvim_get_current_buf)
        (row col) (get-cursor 0)]
    (if (opening-paren? (get-right-char))
      (let [node (ts-utils.get_node_at_cursor)
            (start-row start-col end-row end-col) (-> node (ts-utils.get_node_range))
            last-char (get-char-at buf end-row end-col)] 
        (when (closing-paren? last-char)
          (set-text buf end-row end-col end-row end-col ["" (string.rep " " start-col)]))
        (for [i start-row end-row]
          (let [line-length (get-line-length buf i)
                n (math.max 0 (- start-col line-length))
                begin (if (> start-col line-length) 0 start-col)]
            (set-text buf i begin i begin [(.. (string.rep " " n) ";; ")]))))

      (insert-text-at-cursor buf [fallback]))))

;; TODO: split node-text to lines
(fn raise [fallback]
  (let [buf (api.nvim_get_current_buf) 
        mode (. (api.nvim_get_mode) :mode)] 
    (if (or (= :n mode)
            (and (= :i mode)
                 (opening-paren? (get-right-char))))
      (let [buf (api.nvim_get_current_buf)
            (row col) (get-cursor 0)
            node (ts-utils.get_node_at_cursor)
            (nsr nsc ner nec) (-> node (ts-utils.get_node_range))
            node-text (ts-query.get_node_text node buf)
            lines (vim.split node-text "\n")
            parent (node:parent)
            (psr psc per pec) (-> parent (ts-utils.get_node_range))]
        ;; TODO: add to register
        (set-text buf psr psc per pec [""])
        (set-text buf psr psc psr psc lines)
        ;; (0 1) indexed
        (set-cursor (+ psr 1) psc))
      (when (and (= :i mode) fallback)
        (insert-text-at-cursor buf [fallback])))))


(fn wrap-with [fallback begin end]
  (let [buf (api.nvim_get_current_buf)
        (row col) (get-cursor 0)
        line-length (length (api.nvim_get_current_line))]
    (var i 1)
    (while (< i 3)
      (if (not (= " " (get-right-char)))
        (let [node (ts-utils.get_node_at_cursor)
              node-text (ts-query.get_node_text node buf)
              (start-row start-col end-row end-col) (-> (ts-utils.get_node_at_cursor) (ts-utils.get_node_range))]
          (set-text buf start-row start-col start-row start-col [begin])
          (if (= start-row end-row) 
            (set-text buf end-row (+ end-col 1) end-row (+ end-col 1) [(or end begin)])
            (set-text buf end-row end-col end-row end-col [(or end begin)]))
          (set-cursor (+ start-row 1) (+ start-col 1))
          (set i 3))
        (move-cursor-by 0 1))
      (set i (+ i 1)))
    (if fallback  
      (insert-text-at-cursor buf [fallback]))))

(fn backspace []
  (let [buf (api.nvim_get_current_buf)
        (row col) (get-cursor 0)
        line-length (length (api.nvim_get_current_line))]
    (if (opening-paren? (get-left-char))
      (let [node (ts-utils.get_node_at_cursor)
            (start-row start-col end-row end-col) (ts-utils.get_node_range node)]
        (set-text buf start-row start-col start-row start-col [])))))

{: copy 
 : set-text-at-cursor 
 : insert-text-at-cursor 
 : diffrent
 : find-next-char
 : step-inside
 : delete
 : backspace
 : mark
 :comment comment-node
 : raise
 : wrap-with}
