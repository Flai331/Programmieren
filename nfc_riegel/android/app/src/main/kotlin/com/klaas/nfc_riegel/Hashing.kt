package com.klaas.nfc_riegel

import java.security.MessageDigest

/** SHA-256 als Hexstring. Wird für den Notfall-Code gebraucht. */
object Hashing {
    fun sha256(input: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(input.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
}
