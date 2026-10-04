package com.zdmgold.statussozo

/**
 * Error code strings sent to Dart. Must match lib/core/errors/error_codes.dart.
 */
object ErrorCodes {
    const val ACCESS_LOST = "ACCESS_LOST"
    const val NOT_FOUND = "NOT_FOUND"
    const val IO = "IO"
    const val PERMISSION_LOST = "PERMISSION_LOST"
    const val TOO_LARGE = "TOO_LARGE"
    const val UNSUPPORTED = "UNSUPPORTED"
}

/** An error that already carries one of the [ErrorCodes] strings. */
class NativeException(
    val code: String,
    message: String?,
    cause: Throwable? = null,
) : Exception(message, cause)
