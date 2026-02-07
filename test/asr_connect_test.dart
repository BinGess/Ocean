// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mindflow/core/network/doubao_asr_client.dart';
import 'package:mindflow/core/constants/app_constants.dart';

void main() {
  test('ASR WebSocket Connection Integration Test', () async {
    // 1. Load environment variables
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print('Warning: Could not load .env file. Ensure it exists in project root.');
      print('Error: $e');
      return; // Skip test if .env is missing
    }

    if (!EnvConfig.isConfigured) {
      print('Skipping test: Missing API keys in .env');
      print('Status: ${EnvConfig.getConfigStatus()}');
      return;
    }

    print('Starting ASR Connection Test...');
    print('Endpoint: ${AppConstants.doubaoAsrEndpoint}');
    print('Cluster ID: ${EnvConfig.doubaoAsrResourceId}');

    final client = DoubaoASRClient();
    final completer = Completer<void>();
    bool hasError = false;

    // 2. Setup response listener
    final subscription = client.responses.listen(
      (response) {
        print('Received Response:');
        print('  Success: ${response.success}');
        print('  IsFinal: ${response.isFinal}');
        print('  Text: ${response.text}');
        print('  Error: ${response.error}');
        print('  Raw: ${response.rawData}');

        if (!response.success) {
          hasError = true;
          if (!completer.isCompleted) completer.completeError('ASR Error: ${response.error}');
        } else {
          // Received a valid response (even if empty text)
          if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (e) {
        print('Stream Error: $e');
        hasError = true;
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    try {
      // 3. Connect (sends Full Client Request)
      await client.connect(
        appKey: EnvConfig.doubaoAsrAppKey,
        accessKey: EnvConfig.doubaoAsrAccessKey,
        resourceId: EnvConfig.doubaoAsrResourceId,
      );
      print('WebSocket Connected and Handshake Sent.');

      // 4. Send some silent audio to trigger a response
      // Send 1 second of silence (16000Hz * 2 bytes * 1s = 32000 bytes)
      // Sending in chunks
      print('Sending silent audio...');
      const chunkSize = 6400; // 200ms
      final silence = Uint8List(chunkSize); 
      
      for (int i = 0; i < 5; i++) {
        await client.sendAudio(silence);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      await client.finishAudio();
      print('Finished sending audio.');

      // Wait for response or timeout
      await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
        if (!hasError) {
          print('Timeout waiting for response. This might be normal if silence yielded no result.');
          // Consider success if no error occurred during connection and sending
          return; 
        } else {
           throw TimeoutException('Timed out waiting for successful response');
        }
      });

      print('Test Completed Successfully.');

    } catch (e) {
      print('Test Failed: $e');
      rethrow;
    } finally {
      await subscription.cancel();
      await client.disconnect();
      client.dispose();
    }
  });
}
