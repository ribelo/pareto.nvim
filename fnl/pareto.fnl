
(local api vim.api)
(local contains? vim.tbl_contains)
(local empty? vim.tbl_isempty)

(fn buf-line-count [buf-id]
  (api.nvim_buf_line_count buf-id))

(fn buf-lines [buf-id]
  (api.nvim_buf_get_lines buf-id 0 (buf-line-count buf-id) true))

(fn cursor-pos []
  (api.nvim_win_get_cursor 0))

(fn current-mode []
  (api.nvim_get_mode))

(fn char-at [row col]
  (let [lines (buf-lines 0)]
    (string.sub (. lines row) col col)))

(fn char-at-cursor []
  (char-at (unpack (cursor-pos))))

(fn left-char []
  (let [[row col] (cursor-pos)]
    (match (current-mode)
     {:mode :n} ( . ( api.nvim_buf_get_text 0 (- row 1) col (- row 1) (+ col 1) {}) 1)
     {:mode :i} ( . ( api.nvim_buf_get_text 0 (- row 1) (- col 1) (- row 1) col {}) 1))))

(fn right-char []
  (let [[row col] (cursor-pos)]
    (match (current-mode)
     {:mode :n} ( . ( api.nvim_buf_get_text 0 (- row 1) col (- row 1) (+ col 1) {}) 1)
     {:mode :i} ( . ( api.nvim_buf_get_text 0 (- row 1) col (- row 1) (+ col 1) {}) 1))))

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
  (contains? ["(" "{" "["] x))

(fn closing-paren? [x]  
  (contains? [")" "}" "]"] x))

(fn word-end? [x]
  (or (= " " x) (opening-paren? x) (closing-paren? x)))

(fn find-matching-paren-befor-cursor [lines x ...]
    (let [(row col stack) ...
          row (or row 1)
          col (or col 1)
          stack (or stack [])]
      (when (<= row (length lines))
        (let [line (. lines row)] 
          (if (<= col (length line)) 
            (let [char (string.sub line col col)] 
              (print :char char)
              (if (= 0 (length stack))
                (if (match-paren? char x)
                  [row col]
                  (if (closing-paren? char) 
                    (previous-matching-paren lines x row (- col 1) (doto stack (table.insert char)))
                    (when (not (opening-paren? char)) 
                      (previous-matching-paren lines x row (- col 1) stack))))
                (let [lst (. stack (length stack))]
                  (if (opening-paren? char)
                    (when (match-paren? lst char)
                      (previous-matching-paren lines x row (- col 1) (doto stack (table.remove))))
                    (when (closing-paren? char)
                      (previous-matching-paren lines x row (- col 1) (doto stack (table.insert char))))))))
            (previous-matching-paren lines x (- row 1) 1 stack))))))

(fn find-next-matching-paren [lines x ...]
    (let [(row col stack) ...
          row (or row 1)
          col (or col 1)
          stack (or stack [])]
      (when (<= row (length lines))
        (let [line (. lines row)] 
          (if (<= col (length line)) 
            (let [char (string.sub line col col)] 
              (if (= 0 (length stack))
                (if (match-paren? char x)
                  [row col]
                  (if (opening-paren? char) 
                    (next-matching-paren lines x row (+ col 1) (doto stack (table.insert char)))
                    (when (not (closing-paren? char)) 
                      (next-matching-paren lines x row (+ col 1) stack))))
                (let [lst (. stack (length stack))]
                  (if (closing-paren? char)
                    (when (match-paren? lst char)
                      (next-matching-paren lines x row (+ col 1) (doto stack (table.remove))))
                    (when (opening-paren? char)
                      (next-matching-paren lines x row (+ col 1) (doto stack (table.insert char))))))))
            (next-matching-paren lines x (+ row 1) 1 stack))))))

(right-char)

(fn find-matching-paren []
  (if (opening-paren? (right-char))
      (find-matching-paren-befor-cursor)
      (closing-paren? (left-char))
      (find-matching-paren-after-cursor)))

(fn diffrent []
  (if (opening-paren? (right-char))
      (find-matching-paren)))

(left-char)

{}
