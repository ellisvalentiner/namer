# not elegant, given a part of a header,
# transform it into the row of a tibble
transform_params <- function(params){
  params_string <- try(eval(parse(text = paste('alist(', quote_label(params), ')'))),
               silent = TRUE)

  if(inherits(params_string, "try-error")){
    params <- stringr::str_replace(params, " ", ", ")
    params_string <- eval(parse(text = paste('alist(', quote_label(params), ')')))
  }

  label <- parse_label(params_string[[1]])

  tibble::tibble(language = label$language,
                 name = label$name,
                 options = stringr::str_remove(params, params_string[[1]]))
}


parse_label <- function(label){
  label %>%
    stringr::str_replace(" ", "\\/") %>%
    stringr::str_split("\\/",
                       simplify = TRUE) -> language_name

  if(ncol(language_name) == 1){
    tibble::tibble(language = trimws(language_name[1, 1]),
                   name = NA)
  }else{
    tibble::tibble(language = trimws(language_name[1, 1]),
                   name = trimws(language_name[1, 2]))
  }
}

# from a chunk header
# to a tibble with language, name, option, option values
parse_chunk_header <- function(chunk_header){
  # remove boundaries
  chunk_header %>%
    stringr::str_remove_all("```\\{") %>%
    stringr::str_remove_all("\\}") %>%
    # parse each part
    transform_params()

}

digest_chunk_header <- function(chunk_header_index,
                                lines){
  # parse the chunk header
  lines[chunk_header_index] %>%
    parse_chunk_header -> chunk_info

  # keep index
  chunk_info$index <- chunk_header_index

  chunk_info
}

# helper to go from tibble with chunk info
# to header to write in R Markdown
re_write_headers <- function(info_df){
  info_df %>%
    dplyr::group_by(.data$index) %>%
    dplyr::summarise(line = glue::glue("```{(language[1]) (name[1])(options)}",
                                       .open = "(",
                                       .close = ")"),
                     # for when no name
                     line = stringr::str_replace_all(.data$line, " \\,", ","),
                     line = stringr::str_remove_all(.data$line, " NA"))
}

# helper to create a data.frame of chunk info
get_chunk_info <- function(lines){
  # find which lines are chunk starts
  chunk_header_indices <- which(stringr::str_detect(lines,
                                                    "```\\{[a-zA-Z0-9]"))

  # null if no chunks
  if(length(chunk_header_indices) == 0){
    return(NULL)
  }
  # parse these chunk headers
  purrr::map_df(chunk_header_indices,
                digest_chunk_header,
                lines)
}

# from knitr
# https://github.com/yihui/knitr/blob/2b3e617a700f6d236e22873cfff6cbc3568df568/R/parser.R#L148
# quote the chunk label if necessary
quote_label = function(x) {
  x = gsub('^\\s*,?', '', x)
  if (grepl('^\\s*[^\'"](,|\\s*$)', x)) {
    # <<a,b=1>>= ---> <<'a',b=1>>=
    x = gsub('^\\s*([^\'"])(,|\\s*$)', "'\\1'\\2", x)
  } else if (grepl('^\\s*[^\'"](,|[^=]*(,|\\s*$))', x)) {
    # <<abc,b=1>>= ---> <<'abc',b=1>>=
    x = gsub('^\\s*([^\'"][^=]*)(,|\\s*$)', "'\\1'\\2", x)
  }
  x
}


globalVariables(".data")
