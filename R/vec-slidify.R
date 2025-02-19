#' Rolling Window Transformation
#'
#' `slidify_vec()` applies a _summary function_ to a rolling sequence of windows.
#'
#' @param .x A vector to have a rolling window transformation applied.
#' @param .period The number of periods to include in the local rolling window.
#'  This is effectively the "window size".
#' @param .f A summary `[function / formula]`
#'
#'   - If a __function__, e.g. `mean`, the function is used with any
#'    additional arguments, `...`.
#'
#'   - If a __formula__, e.g. `~ mean(., na.rm = TRUE)`, it is converted to a function.
#'
#'   This syntax allows you to create very compact anonymous functions.
#'
#' @param ... Additional arguments passed on to the `.f` function.
#' @param .align One of "center", "left" or "right".
#' @param .partial Should the moving window be allowed to return partial (incomplete) windows instead of `NA` values.
#'  Set to FALSE by default, but can be switched to TRUE to remove `NA`'s.
#'
#' @return A numeric vector
#'
#' @details
#' The `slidify_vec()` function is a wrapper for `slider::slide_vec()` with parameters
#' simplified "center", "left", "right" alignment.
#'
#' __Vector Length In == Vector Length Out__
#'
#' `NA` values or `.partial` values
#' are always returned to ensure the length of the return vector
#' is the same length of the incoming vector. This ensures easier use with `dplyr::mutate()`.
#'
#' __Alignment__
#'
#' Rolling functions generate `.period - 1` fewer values than the incoming vector.
#' Thus, the vector needs to be aligned. Alignment of the vector follows 3 types:
#'
#'  - __Center:__ `NA` or `.partial` values are divided and added to the beginning and
#'    end of the series to "Center" the moving average.
#'    This is common for de-noising operations. See also `[smooth_vec()]` for LOESS without NA values.
#'  - __Left:__ `NA` or `.partial` values are added to the end to shift the series to the Left.
#'  - __Right:__ `NA` or `.partial` values are added to the beginning to shif the series to the Right. This is common in
#'    Financial Applications such as moving average cross-overs.
#'
#' __Partial Values__
#'
#' - The advantage to using `.partial` values vs `NA` padding is that
#' the series can be filled (good for time-series de-noising operations).
#' - The downside to partial values is that the partials can become less stable
#' at the regions where incomplete windows are used.
#'
#' If instability is not desirable for de-noising operations, a suitable alternative
#' is [`smooth_vec()`], which implements local polynomial regression.
#'
#' @seealso
#'
#' Modeling and More Complex Rolling Operations:
#'   - [step_slidify()] - Roll apply for `tidymodels` modeling
#'   - [tk_augment_slidify()] - Add many rolling columns group-wise
#'   - [slidify()] - Turn any function into a rolling function. Great for
#'     rolling cor, rolling regression, etc.
#'   - For more complex rolling operations, check out the `slider` R package.
#'
#' Vectorized Transformation Functions:
#'
#'   - Box Cox Transformation: [box_cox_vec()]
#'   - Lag Transformation: [lag_vec()]
#'   - Differencing Transformation: [diff_vec()]
#'   - Rolling Window Transformation: [slidify_vec()]
#'   - Loess Smoothing Transformation: [smooth_vec()]
#'   - Fourier Series: [fourier_vec()]
#'   - Missing Value Imputation for Time Series: [ts_impute_vec()]
#'
#'
#' @references
#'
#' - [Slider R Package](https://slider.r-lib.org/) by Davis Vaughan
#'
#' @examples
#' library(tidyverse)
#' library(tidyquant)
#' library(timetk)
#'
#' # Training Data
#' FB_tbl <- FANG %>%
#'     filter(symbol == "FB") %>%
#'     select(symbol, date, adjusted)
#'
#' # ---- FUNCTION FORMAT ----
#' # - The `.f = mean` function is used. Argument `na.rm = TRUE` is passed as ...
#' FB_tbl %>%
#'     mutate(adjusted_30_ma = slidify_vec(
#'         .x      = adjusted,
#'         .period = 30,
#'         .f      = mean,
#'         na.rm   = TRUE,
#'         .align  = "center")) %>%
#'         ggplot(aes(date, adjusted)) +
#'         geom_line() +
#'         geom_line(aes(y = adjusted_30_ma), color = "blue")
#'
#' # ---- FORMULA FORMAT ----
#' # - Anonymous function `.f = ~ mean(., na.rm = TRUE)` is used
#' FB_tbl %>%
#'     mutate(adjusted_30_ma = slidify_vec(
#'         .x      = adjusted,
#'         .period = 30,
#'         .f      = ~ mean(., na.rm = TRUE),
#'         .align  = "center")) %>%
#'         ggplot(aes(date, adjusted)) +
#'         geom_line() +
#'         geom_line(aes(y = adjusted_30_ma), color = "blue")
#'
#' # ---- PARTIAL VALUES ----
#' # - set `.partial = TRUE`
#' FB_tbl %>%
#'     mutate(adjusted_30_ma = slidify_vec(
#'         .x       = adjusted,
#'         .f       = ~ mean(., na.rm = TRUE),
#'         .period  = 30,
#'         .align   = "center",
#'         .partial = TRUE)) %>%
#'         ggplot(aes(date, adjusted)) +
#'         geom_line() +
#'         geom_line(aes(y = adjusted_30_ma), color = "blue")
#'
#' # ---- Loess vs Moving Average ----
#' # - Loess: Using `.degree = 0` to make less flexible. Comperable to a moving average.
#'
#' FB_tbl %>%
#'     mutate(
#'         adjusted_loess_30 = smooth_vec(adjusted, period = 30, degree = 0),
#'         adjusted_ma_30    = slidify_vec(adjusted, .f = AVERAGE,
#'                                            .period = 30, .partial = TRUE)
#'     ) %>%
#'     ggplot(aes(date, adjusted)) +
#'     geom_line() +
#'     geom_line(aes(y = adjusted_loess_30), color = "red") +
#'     geom_line(aes(y = adjusted_ma_30), color = "blue") +
#'     labs(title = "Loess vs Moving Average")
#'
#'
#'
#' @export
slidify_vec <- function(.x, .f, ..., .period = 1, .align = c("center", "left", "right"), .partial = FALSE) {

    # if (!is.numeric(.x)) rlang::abort("Non-numeric data detected. 'x' must be numeric.")

    roll_to_slide(
        .slider_fun = slider::slide_vec,
        .x          = .x,
        .period     = .period,
        .f          = .f,
        ...,
        .align      = .align,
        .partial    = .partial
    )

}

# UTILS -----

roll_to_slide <- function(.slider_fun, ..., .period = 1, .align = c("center", "left", "right"), .partial = FALSE) {

    # Calculate alignment padding
    .align <- .align[1]
    if (.align == "center") {

        split_period <- (.period - 1) / 2

        before       <- floor(split_period)
        after        <- ceiling(split_period)
    } else if (.align == "left") {
        before <- 0
        after  <- .period - 1
    } else {
        before <- .period - 1
        after  <- 0
    }

    # Get slide
    vec <- .slider_fun(
        ...,
        .before   = before,
        .after    = after,
        .step     = 1L,
        .complete = FALSE
    )

    # Apply NA padding if partial is not allowed
    if (!.partial) {
        if (before > 0) vec[1:before] <- NA
        if (after > 0)  vec[(length(vec) - after + 1):length(vec)] <- NA
    }

    return(vec)

}

