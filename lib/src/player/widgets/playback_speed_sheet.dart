import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

/// A bottom-sheet style widget for selecting video playback speed.
class PlaybackSpeedSheet extends StatefulWidget {
  final double currentSpeed;
  final Function(double) onSpeedSelected;
  final bool isLandscape;

  const PlaybackSpeedSheet({
    required this.currentSpeed,
    required this.onSpeedSelected,
    this.isLandscape = false,
    super.key,
  });

  @override
  State<PlaybackSpeedSheet> createState() => _PlaybackSpeedSheetState();
}

class _PlaybackSpeedSheetState extends State<PlaybackSpeedSheet> {
  late double _currentSpeed;

  static const _cardBackground = Color(0xFF1C1C2E);
  static const _hintColor = Color(0xFF3A3A3C);
  static const _textColor = Colors.white;
  static const _selectedColor = Color(0xFF4285F4);

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.currentSpeed;
  }

  @override
  void didUpdateWidget(covariant PlaybackSpeedSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSpeed != widget.currentSpeed) {
      _currentSpeed = widget.currentSpeed;
    }
  }

  void _updateSpeed(double newSpeed) {
    setState(() {
      _currentSpeed = newSpeed;
    });
    widget.onSpeedSelected(newSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final speeds = [1.0, 1.25, 1.5, 2.0, 3.0];
    return Column(
      children: [
        const Spacer(),
        SafeArea(
          child: SlideInUp(
            duration: const Duration(milliseconds: 100),
            child: SizedBox(
              width: widget.isLandscape ? 400 : double.infinity,
              child: Card(
                margin: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: widget.isLandscape ? 16 : 0,
                ),
                color: _cardBackground,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        width: 45,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _hintColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        '${_currentSpeed.toStringAsFixed(2)}x',
                        style: const TextStyle(
                          color: _textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              final newSpeed = (_currentSpeed - 0.25).clamp(
                                0.5,
                                3.0,
                              );
                              _updateSpeed(newSpeed);
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.remove,
                                color: _textColor,
                                size: 22,
                              ),
                            ),
                          ),

                          Expanded(
                            child: Slider(
                              value: _currentSpeed,
                              min: 0.5,
                              max: 3.0,
                              divisions: 10,
                              activeColor: _selectedColor,
                              inactiveColor: _hintColor,
                              onChanged: _updateSpeed,
                            ),
                          ),

                          InkWell(
                            onTap: () {
                              final newSpeed = (_currentSpeed + 0.25).clamp(
                                0.5,
                                3.0,
                              );
                              _updateSpeed(newSpeed);
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.add,
                                color: _textColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(color: _hintColor, height: 1),
                      const SizedBox(height: 4),

                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: speeds.map((speed) {
                          final isSelected = _currentSpeed == speed;
                          return ChoiceChip(
                            label: Text(
                              '${speed}x',
                              style: TextStyle(
                                color: isSelected ? Colors.white : _textColor,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: _selectedColor,
                            backgroundColor: _hintColor,
                            onSelected: (_) => _updateSpeed(speed),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 0,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
