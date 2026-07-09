package com.qroadscan.lightcal

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), RecognitionListener, TextToSpeech.OnInitListener {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val liveVoiceChannelName = "com.nazaone/live_voice"
    private val recordPermissionRequest = 4224

    private var liveVoiceChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var listenResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var speakResult: MethodChannel.Result? = null
    private var speakUtteranceId: String? = null
    private var pendingSpeakText: String? = null
    private var pendingSpeakRate = 0.98f
    private var pendingSpeakPitch = 1.0f

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liveVoiceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            liveVoiceChannelName
        )
        liveVoiceChannel?.setMethodCallHandler(::handleLiveVoiceCall)
        ensureTts()
    }

    private fun handleLiveVoiceCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(SpeechRecognizer.isRecognitionAvailable(this))
            "requestRecordPermission" -> requestRecordPermission(result)
            "listenOnce" -> listenOnce(call, result)
            "speak" -> speak(call, result)
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

        listenResult = result
        ensureSpeechRecognizer()

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
            liveVoiceChannel?.invokeMethod("voiceListening", emptyMap<String, Any>())
            speechRecognizer?.startListening(intent)
        } catch (error: Throwable) {
            finishListenWithError("listen_failed", error.message ?: "Speech recognizer failed.")
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
        ensureTts()
        if (ttsReady) {
            startPendingSpeak()
        }
    }

    private fun ensureSpeechRecognizer() {
        if (speechRecognizer != null) return
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).also {
            it.setRecognitionListener(this)
        }
    }

    private fun ensureTts() {
        if (tts != null) return
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        ttsReady = status == TextToSpeech.SUCCESS
        if (!ttsReady) {
            finishSpeakWithError("tts_init_failed", "System text-to-speech did not initialize.")
            return
        }
        tts?.setLanguage(Locale.getDefault())
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                liveVoiceChannel?.invokeMethod("voiceTtsStart", mapOf("id" to (utteranceId ?: "")))
            }

            override fun onDone(utteranceId: String?) {
                if (utteranceId != speakUtteranceId) return
                mainHandler.post {
                    liveVoiceChannel?.invokeMethod("voiceTtsDone", mapOf("id" to (utteranceId ?: "")))
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
                    finishSpeakWithError("tts_error", "System TTS failed with code $errorCode.")
                }
            }
        })
        startPendingSpeak()
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
        liveVoiceChannel?.invokeMethod("voiceListening", emptyMap<String, Any>())
    }

    override fun onBeginningOfSpeech() {
        liveVoiceChannel?.invokeMethod("voiceSpeechStart", emptyMap<String, Any>())
    }

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() {
        liveVoiceChannel?.invokeMethod("voiceSpeechEnd", emptyMap<String, Any>())
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
            liveVoiceChannel?.invokeMethod("voicePartial", mapOf("transcript" to partial))
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

    private fun stopLiveVoice() {
        try {
            speechRecognizer?.cancel()
        } catch (_: Throwable) {
        }
        listenResult?.success(mapOf("transcript" to "", "confidence" to null))
        listenResult = null

        try {
            tts?.stop()
        } catch (_: Throwable) {
        }
        speakResult?.success(false)
        speakResult = null
        speakUtteranceId = null
        pendingSpeakText = null
    }

    override fun onDestroy() {
        stopLiveVoice()
        speechRecognizer?.destroy()
        speechRecognizer = null
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
