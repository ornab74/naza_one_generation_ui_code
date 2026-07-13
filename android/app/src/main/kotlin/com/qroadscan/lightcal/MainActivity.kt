package com.qroadscan.lightcal

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity(), RecognitionListener, TextToSpeech.OnInitListener {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val liveVoiceChannelName = "com.nazaone/live_voice"
    private val recordPermissionRequest = 4224
    private val imagePickerRequest = 4225
    private val maxImageSourceBytes = 32L * 1024L * 1024L
    private val maxVisionImageDimension = 1280

    private var liveVoiceChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var listenResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null
    private var imageResult: MethodChannel.Result? = null
    private var destroyed = false

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var speakResult: MethodChannel.Result? = null
    private var speakUtteranceId: String? = null
    private var pendingSpeakText: String? = null
    private var pendingSpeakRate = 0.98f
    private var pendingSpeakPitch = 1.0f
    private var mediaPlayer: MediaPlayer? = null
    private var playbackResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liveVoiceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            liveVoiceChannelName
        )
        liveVoiceChannel?.setMethodCallHandler(::handleLiveVoiceCall)
    }

    private fun handleLiveVoiceCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(SpeechRecognizer.isRecognitionAvailable(this))
            "requestRecordPermission" -> requestRecordPermission(result)
            "listenOnce" -> listenOnce(call, result)
            "speak" -> speak(call, result)
            "playWav" -> playWav(call, result)
            "pickImage" -> pickImage(result)
            "stopListening" -> {
                stopListening()
                result.success(null)
            }
            "stopAudio" -> {
                stopSpeaking()
                stopPlayback()
                result.success(null)
            }
            "stop" -> {
                stopLiveVoice()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestRecordPermission(result: MethodChannel.Result) {
        if (hasRecordPermission()) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("permission_busy", "A microphone permission request is already active.", null)
            return
        }
        permissionResult = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), recordPermissionRequest)
        } else {
            finishPermissionRequest(true)
        }
    }

    private fun listenOnce(call: MethodCall, result: MethodChannel.Result) {
        if (!hasRecordPermission()) {
            result.error("microphone_denied", "Microphone permission has not been granted.", null)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("speech_unavailable", "Speech recognition is not available on this device.", null)
            return
        }
        if (listenResult != null) {
            result.error("listen_busy", "A live voice listen request is already active.", null)
            return
        }

        val completeSilenceMs = call.argument<Int>("completeSilenceMs") ?: 850
        val possibleSilenceMs = call.argument<Int>("possibleSilenceMs") ?: 450
        val minimumSpeechMs = call.argument<Int>("minimumSpeechMs") ?: 450
        val preferOffline = call.argument<Boolean>("preferOffline") ?: true

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, preferOffline)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                completeSilenceMs
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                possibleSilenceMs
            )
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, minimumSpeechMs)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                putExtra(
                    RecognizerIntent.EXTRA_ENABLE_FORMATTING,
                    RecognizerIntent.FORMATTING_OPTIMIZE_LATENCY
                )
            }
        }

        try {
            ensureSpeechRecognizer()
            listenResult = result
            emitVoiceEvent("voiceListening", emptyMap())
            speechRecognizer?.startListening(intent)
        } catch (error: Throwable) {
            listenResult = null
            result.error("listen_failed", error.message ?: "Speech recognizer failed.", null)
        }
    }

    private fun speak(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")?.trim().orEmpty()
        if (text.isEmpty()) {
            result.success(false)
            return
        }
        if (speakResult != null) {
            tts?.stop()
            speakResult?.success(false)
            speakResult = null
        }

        speakResult = result
        pendingSpeakText = text.take(TextToSpeech.getMaxSpeechInputLength().coerceAtMost(3800))
        pendingSpeakRate = (call.argument<Double>("rate") ?: 0.98).toFloat().coerceIn(0.6f, 1.35f)
        pendingSpeakPitch = (call.argument<Double>("pitch") ?: 1.0).toFloat().coerceIn(0.7f, 1.4f)
        try {
            ensureTts()
        } catch (error: Throwable) {
            finishSpeakWithError(
                "tts_start_failed",
                error.message ?: "System text-to-speech could not start."
            )
            return
        }
        if (ttsReady) {
            startPendingSpeak()
        } else {
            mainHandler.postDelayed({
                if (speakResult === result && !ttsReady) {
                    try {
                        tts?.shutdown()
                    } catch (_: Throwable) {
                    }
                    tts = null
                    finishSpeakWithError(
                        "tts_init_timeout",
                        "System text-to-speech did not initialize in time."
                    )
                }
            }, 8000)
        }
    }

    private fun ensureSpeechRecognizer() {
        if (speechRecognizer != null) return
        check(!destroyed) { "Voice bridge is closing." }
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).also {
            it.setRecognitionListener(this)
        }
    }

    private fun ensureTts() {
        if (tts != null) return
        check(!destroyed) { "Voice bridge is closing." }
        ttsReady = false
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        if (destroyed) return
        ttsReady = status == TextToSpeech.SUCCESS
        if (!ttsReady) {
            try {
                tts?.shutdown()
            } catch (_: Throwable) {
            }
            tts = null
            finishSpeakWithError("tts_init_failed", "System text-to-speech did not initialize.")
            return
        }
        val languageStatus = tts?.setLanguage(Locale.getDefault()) ?: TextToSpeech.ERROR
        if (languageStatus == TextToSpeech.LANG_MISSING_DATA ||
            languageStatus == TextToSpeech.LANG_NOT_SUPPORTED ||
            languageStatus == TextToSpeech.ERROR
        ) {
            ttsReady = false
            try {
                tts?.shutdown()
            } catch (_: Throwable) {
            }
            tts = null
            finishSpeakWithError(
                "tts_language_unavailable",
                "System text-to-speech does not support the current language."
            )
            return
        }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                mainHandler.post {
                    if (utteranceId != speakUtteranceId) return@post
                    emitVoiceEvent(
                        "voiceTtsStart",
                        mapOf("id" to (utteranceId ?: ""))
                    )
                }
            }

            override fun onDone(utteranceId: String?) {
                if (utteranceId != speakUtteranceId) return
                mainHandler.post {
                    if (utteranceId != speakUtteranceId) return@post
                    emitVoiceEvent(
                        "voiceTtsDone",
                        mapOf("id" to (utteranceId ?: ""))
                    )
                    speakResult?.success(true)
                    speakResult = null
                    speakUtteranceId = null
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                onError(utteranceId, TextToSpeech.ERROR)
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                if (utteranceId != speakUtteranceId) return
                mainHandler.post {
                    if (utteranceId != speakUtteranceId) return@post
                    finishSpeakWithError("tts_error", "System TTS failed with code $errorCode.")
                }
            }
        })
        startPendingSpeak()
    }

    private fun pickImage(result: MethodChannel.Result) {
        if (imageResult != null) {
            result.error("image_picker_busy", "An image picker is already open.", null)
            return
        }
        imageResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("image/jpeg", "image/png", "image/webp", "image/heic", "image/heif")
            )
        }
        try {
            startActivityForResult(intent, imagePickerRequest)
        } catch (error: Throwable) {
            imageResult = null
            result.error(
                "image_picker_unavailable",
                error.message ?: "No Android image picker is available.",
                null
            )
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != imagePickerRequest) return

        val uri = data?.data ?: data?.clipData?.let { clips ->
            if (clips.itemCount > 0) clips.getItemAt(0).uri else null
        }
        if (resultCode != Activity.RESULT_OK || uri == null) {
            imageResult?.success(null)
            imageResult = null
            return
        }

        Thread {
            try {
                val payload = prepareVisionImage(uri)
                mainHandler.post {
                    imageResult?.success(payload)
                    imageResult = null
                }
            } catch (error: Throwable) {
                mainHandler.post {
                    imageResult?.error(
                        "image_decode_failed",
                        error.message ?: "The selected image could not be prepared.",
                        null
                    )
                    imageResult = null
                }
            }
        }.start()
    }

    private fun prepareVisionImage(uri: Uri): Map<String, Any> {
        val resolver = contentResolver
        resolver.openAssetFileDescriptor(uri, "r")?.use { descriptor ->
            val length = descriptor.length
            require(length < 0 || length <= maxImageSourceBytes) {
                "The selected image is larger than the 32 MB safety limit."
            }
        }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, bounds)
        } ?: error("The selected image cannot be opened.")
        require(bounds.outWidth > 0 && bounds.outHeight > 0) {
            "The selected file is not a supported image."
        }

        var sample = 1
        while (bounds.outWidth / sample > maxVisionImageDimension * 2 ||
            bounds.outHeight / sample > maxVisionImageDimension * 2
        ) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = resolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, options)
        } ?: error("Android could not decode the selected image.")

        val scale = minOf(
            1.0,
            maxVisionImageDimension.toDouble() / maxOf(decoded.width, decoded.height).toDouble()
        )
        val prepared = if (scale < 1.0) {
            Bitmap.createScaledBitmap(
                decoded,
                (decoded.width * scale).toInt().coerceAtLeast(1),
                (decoded.height * scale).toInt().coerceAtLeast(1),
                true
            )
        } else {
            decoded
        }

        val output = ByteArrayOutputStream()
        try {
            check(prepared.compress(Bitmap.CompressFormat.JPEG, 88, output)) {
                "Android could not normalize the selected image."
            }
            val bytes = output.toByteArray()
            require(bytes.size <= 8 * 1024 * 1024) {
                "The prepared image exceeds the 8 MB vision limit."
            }
            return mapOf(
                "bytes" to bytes,
                "name" to imageDisplayName(uri),
                "width" to prepared.width,
                "height" to prepared.height
            )
        } finally {
            output.close()
            if (prepared !== decoded) prepared.recycle()
            decoded.recycle()
        }
    }

    private fun imageDisplayName(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0) return cursor.getString(index) ?: "image.jpg"
                    }
                }
        } catch (_: Throwable) {
        }
        return "image.jpg"
    }

    private fun playWav(call: MethodCall, result: MethodChannel.Result) {
        val rawPath = call.argument<String>("path")?.trim().orEmpty()
        if (rawPath.isEmpty()) {
            result.error("wav_path_empty", "No local WAV path was provided.", null)
            return
        }

        val file = try {
            File(rawPath).canonicalFile
        } catch (error: Throwable) {
            result.error("wav_path_invalid", error.message ?: "Invalid WAV path.", null)
            return
        }
        val filesRoot = filesDir.canonicalFile.path + File.separator
        val cacheRoot = cacheDir.canonicalFile.path + File.separator
        if ((!file.path.startsWith(filesRoot) && !file.path.startsWith(cacheRoot)) ||
            !file.name.lowercase(Locale.ROOT).endsWith(".wav")
        ) {
            result.error("wav_path_rejected", "Only app-local WAV files can be played.", null)
            return
        }
        if (!file.isFile || file.length() <= 44L) {
            result.error("wav_missing", "The rendered WAV file is missing or empty.", null)
            return
        }

        stopPlayback()
        val player = MediaPlayer()
        mediaPlayer = player
        playbackResult = result
        try {
            player.setDataSource(file.path)
            player.setOnPreparedListener {
                if (mediaPlayer !== it || destroyed) {
                    try {
                        it.release()
                    } catch (_: Throwable) {
                    }
                    return@setOnPreparedListener
                }
                try {
                    it.start()
                    if (playbackResult === result) {
                        playbackResult = null
                        result.success(true)
                    }
                    emitVoiceEvent(
                        "voiceAudioStart",
                        mapOf("path" to file.path)
                    )
                } catch (error: Throwable) {
                    if (mediaPlayer === it) mediaPlayer = null
                    try {
                        it.release()
                    } catch (_: Throwable) {
                    }
                    if (playbackResult === result) {
                        playbackResult = null
                        result.error(
                            "wav_playback_failed",
                            error.message ?: "Android could not start WAV playback.",
                            null
                        )
                    }
                }
            }
            player.setOnCompletionListener {
                if (mediaPlayer === it) mediaPlayer = null
                try {
                    it.release()
                } catch (_: Throwable) {
                }
                emitVoiceEvent(
                    "voiceAudioDone",
                    mapOf("path" to file.path)
                )
            }
            player.setOnErrorListener { failed, what, extra ->
                if (mediaPlayer === failed) mediaPlayer = null
                try {
                    failed.release()
                } catch (_: Throwable) {
                }
                if (playbackResult === result) {
                    playbackResult = null
                    result.error(
                        "wav_playback_failed",
                        "Android audio playback failed ($what/$extra).",
                        null
                    )
                }
                true
            }
            player.prepareAsync()
        } catch (error: Throwable) {
            if (mediaPlayer === player) mediaPlayer = null
            player.release()
            if (playbackResult === result) {
                playbackResult = null
                result.error(
                    "wav_playback_failed",
                    error.message ?: "Android could not play the rendered WAV.",
                    null
                )
            }
        }
    }

    private fun startPendingSpeak() {
        val text = pendingSpeakText ?: return
        val engine = tts ?: return
        pendingSpeakText = null
        speakUtteranceId = "naza-tts-${System.currentTimeMillis()}"
        engine.setSpeechRate(pendingSpeakRate)
        engine.setPitch(pendingSpeakPitch)
        val queued = engine.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), speakUtteranceId)
        if (queued == TextToSpeech.ERROR) {
            finishSpeakWithError("tts_queue_failed", "System TTS could not queue the response.")
        }
    }

    private fun hasRecordPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == recordPermissionRequest) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            finishPermissionRequest(granted)
        }
    }

    private fun finishPermissionRequest(granted: Boolean) {
        permissionResult?.success(granted)
        permissionResult = null
    }

    override fun onReadyForSpeech(params: Bundle?) {
        emitVoiceEvent("voiceListening", emptyMap())
    }

    override fun onBeginningOfSpeech() {
        emitVoiceEvent("voiceSpeechStart", emptyMap())
    }

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() {
        emitVoiceEvent("voiceSpeechEnd", emptyMap())
    }

    override fun onError(error: Int) {
        if (error == SpeechRecognizer.ERROR_NO_MATCH ||
            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT
        ) {
            finishListenWithSuccess("", null)
            return
        }
        val message = when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording failed."
            SpeechRecognizer.ERROR_CLIENT -> "Speech recognizer client error."
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission was denied."
            SpeechRecognizer.ERROR_NETWORK -> "Speech recognizer network error."
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Speech recognizer network timeout."
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognizer is busy."
            SpeechRecognizer.ERROR_SERVER -> "Speech recognizer server error."
            else -> "Speech recognizer error $error."
        }
        finishListenWithError("speech_$error", message)
    }

    override fun onResults(results: Bundle?) {
        val matches = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            .orEmpty()
        val confidences = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
        finishListenWithSuccess(matches.firstOrNull().orEmpty(), confidences?.firstOrNull())
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val partial = partialResults
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            .orEmpty()
            .firstOrNull()
            .orEmpty()
        if (partial.isNotBlank()) {
            emitVoiceEvent("voicePartial", mapOf("transcript" to partial))
        }
    }

    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    private fun finishListenWithSuccess(transcript: String, confidence: Float?) {
        val result = listenResult ?: return
        listenResult = null
        result.success(
            mapOf(
                "transcript" to transcript,
                "confidence" to confidence
            )
        )
    }

    private fun finishListenWithError(code: String, message: String) {
        val result = listenResult ?: return
        listenResult = null
        result.error(code, message, null)
    }

    private fun finishSpeakWithError(code: String, message: String) {
        speakResult?.error(code, message, null)
        speakResult = null
        speakUtteranceId = null
        pendingSpeakText = null
    }

    private fun emitVoiceEvent(method: String, arguments: Map<String, Any>) {
        if (destroyed) return
        try {
            liveVoiceChannel?.invokeMethod(method, arguments)
        } catch (_: Throwable) {
            // The Flutter engine can detach while Android is finishing an
            // asynchronous audio callback. Native cleanup must still finish.
        }
    }

    private fun stopListening() {
        val pendingListen = listenResult
        listenResult = null
        try {
            speechRecognizer?.cancel()
        } catch (_: Throwable) {
        }
        pendingListen?.success(mapOf("transcript" to "", "confidence" to null))
    }

    private fun stopSpeaking() {
        val pendingSpeak = speakResult
        speakResult = null
        try {
            tts?.stop()
        } catch (_: Throwable) {
        }
        pendingSpeak?.success(false)
        speakUtteranceId = null
        pendingSpeakText = null
    }

    private fun stopPlayback() {
        val player = mediaPlayer
        mediaPlayer = null
        val pendingPlayback = playbackResult
        playbackResult = null
        try {
            player?.stop()
        } catch (_: Throwable) {
        }
        try {
            player?.release()
        } catch (_: Throwable) {
        }
        pendingPlayback?.success(false)
        emitVoiceEvent("voiceAudioDone", emptyMap())
    }

    private fun stopLiveVoice() {
        stopListening()
        stopSpeaking()
        stopPlayback()
    }

    override fun onDestroy() {
        destroyed = true
        liveVoiceChannel?.setMethodCallHandler(null)
        stopLiveVoice()
        permissionResult?.success(false)
        permissionResult = null
        try {
            imageResult?.error(
                "image_picker_interrupted",
                "Android interrupted image selection. Reopen the picker after the app resumes.",
                null
            )
        } catch (_: Throwable) {
        }
        imageResult = null
        speechRecognizer?.destroy()
        speechRecognizer = null
        tts?.shutdown()
        tts = null
        ttsReady = false
        liveVoiceChannel = null
        super.onDestroy()
    }
}
