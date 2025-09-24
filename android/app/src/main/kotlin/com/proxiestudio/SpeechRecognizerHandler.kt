package com.proxiestudio.blindnavaiv3

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import java.util.Locale

class SpeechRecognizerHandler(
    private val activity: Activity,
    private val callback: (String?) -> Unit
) {
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var triedFallback = false

    fun startListening() {
        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            Log.e("SpeechRecognizer", "Speech recognition not available on device.")
            callback("Speech recognition not available.")
            return
        }

        stop()

        val intent = getRecognizerIntent(preferOffline = !triedFallback)

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(activity).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    isListening = true
                    Log.d("SpeechRecognizer", "Ready for speech")
                }

                override fun onBeginningOfSpeech() {
                    Log.d("SpeechRecognizer", "Speech started")
                }

                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    Log.d("SpeechRecognizer", "Speech ended")
                    isListening = false
                }

                override fun onError(error: Int) {
                    val errorMessage = when (error) {
                        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                        SpeechRecognizer.ERROR_CLIENT -> "Client side error"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                        SpeechRecognizer.ERROR_NETWORK -> "Network error"
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                        SpeechRecognizer.ERROR_NO_MATCH -> "No match found"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy"
                        SpeechRecognizer.ERROR_SERVER -> "Server error"
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout"
                        else -> "Unknown error"
                    }

                    Log.e("SpeechRecognizer", "onError($error): $errorMessage")
                    if (error == SpeechRecognizer.ERROR_SERVER && !triedFallback) {
                        Log.w("SpeechRecognizer", "Retrying with online recognition...")
                        triedFallback = true
                        startListening()
                    } else {
                        isListening = false
                        callback(null)
                    }
                }

                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val spokenText = matches?.getOrNull(0)
                    Log.d("SpeechRecognizer", "Results: $spokenText")
                    isListening = false
                    triedFallback = false
                    callback(spokenText)
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val partial = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.getOrNull(0)
                    Log.d("SpeechRecognizer", "Partial: $partial")
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            startListening(intent)
            Log.d("SpeechRecognizer", "Listening started...")
        }
    }

    private fun getRecognizerIntent(preferOffline: Boolean): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            //putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            //putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US");
            //putExtra(RecognizerIntent.EXTRA_LANGUAGE, "") 
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "de-DE")  
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
        }
    }

    fun stop() {
        if (isListening) {
            try {
                Log.d("SpeechRecognizer", "Stopping recognizer...")
                speechRecognizer?.stopListening()
            } catch (e: Exception) {
                Log.e("SpeechRecognizer", "stopListening() failed: ${e.message}")
            }
        }
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
        isListening = false
    }
}
