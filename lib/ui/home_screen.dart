import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'widgets/status_indicator.dart';
import 'widgets/mute_button.dart';
import 'widgets/audio_visualizer.dart';
import 'widgets/detection_table.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize after first frame (don't auto-start listening)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AppProvider>();
      await provider.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.status == AppStatus.initializing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF58A6FF),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Loading models...',
                    style: TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.status == AppStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Error',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => provider.initialize(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF58A6FF),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Microphone selection dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: provider.isMicSilent
                          ? Colors.orange
                          : const Color(0xFF30363D),
                      width: provider.isMicSilent ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        provider.isMicSilent ? Icons.mic_off : Icons.mic,
                        color: provider.isMicSilent
                            ? Colors.orange
                            : const Color(0xFF58A6FF),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: provider.selectedDeviceId,
                            hint: Text(
                              provider.audioDevices.isEmpty
                                  ? 'No microphones found'
                                  : 'Select microphone',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            dropdownColor: const Color(0xFF161B22),
                            isExpanded: true,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF58A6FF),
                            ),
                            items: provider.audioDevices.map((device) {
                              return DropdownMenuItem<String>(
                                value: device.id,
                                child: Text(
                                  device.label.isNotEmpty
                                      ? device.label
                                      : 'Device ${device.id}',
                                  style: const TextStyle(
                                    color: Color(0xFFE6EDF3),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (deviceId) {
                              provider.selectDevice(deviceId);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: Color(0xFF58A6FF),
                          size: 20,
                        ),
                        onPressed: () => provider.refreshDevices(),
                        tooltip: 'Refresh devices',
                      ),
                    ],
                  ),
                ),
                // Silent mic warning
                if (provider.isMicSilent)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Microphone is producing silence. Try selecting a different microphone.',
                            style: TextStyle(color: Colors.orange[200], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Threshold slider
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF30363D),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Detection Threshold',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${(provider.threshold * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Color(0xFF58A6FF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF58A6FF),
                          inactiveTrackColor: const Color(0xFF30363D),
                          thumbColor: const Color(0xFF58A6FF),
                          overlayColor: const Color(0xFF58A6FF).withAlpha(32),
                        ),
                        child: Slider(
                          value: provider.threshold,
                          min: 0.1,
                          max: 0.9,
                          onChanged: (value) => provider.setThreshold(value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Status section
                Center(
                  child: StatusIndicator(
                    isListening: provider.isListening,
                    isMuted: provider.isMuted,
                    confidence: provider.currentConfidence,
                  ),
                ),
                const SizedBox(height: 24),

                // Audio visualizer
                AudioVisualizer(
                  level: provider.audioLevel,
                  isActive: provider.isListening && !provider.isMuted,
                ),
                const SizedBox(height: 24),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MuteButton(
                      isMuted: provider.isMuted,
                      onPressed: provider.toggleMute,
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (provider.isListening) {
                          provider.stopListening();
                        } else {
                          provider.startListening();
                        }
                      },
                      icon: Icon(
                        provider.isListening ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(provider.isListening ? 'STOP' : 'START'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: provider.isListening
                            ? Colors.red[700]
                            : const Color(0xFF3FB950),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Detection history table
                Expanded(
                  child: DetectionTable(
                    detections: provider.detections,
                    onClear: provider.clearDetections,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
