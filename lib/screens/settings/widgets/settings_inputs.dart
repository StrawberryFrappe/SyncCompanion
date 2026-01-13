import 'package:flutter/material.dart';

/// Reusable widget for editing stat rate values with a dialog.
class RateInput extends StatelessWidget {
  final String label;
  final double currentRate;
  final ValueChanged<double> onApply;

  const RateInput({
    super.key,
    required this.label,
    required this.currentRate,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final percentOver10s = (currentRate * 10 * 100).toStringAsFixed(1);
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                Text('$percentOver10s% / 10s  (${(currentRate * 100).toStringAsFixed(3)}%/s)', 
                  style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
              ),
              onPressed: () => _showRateEditDialog(context),
              child: const Text('EDIT', style: TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showRateEditDialog(BuildContext context) async {
    final percentController = TextEditingController(text: (currentRate * 10 * 100).toStringAsFixed(1));
    final secondsController = TextEditingController(text: '10');
    
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set rate as N% over T seconds:', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: percentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Percent',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('over'),
                ),
                Expanded(
                  child: TextField(
                    controller: secondsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Seconds',
                      suffixText: 's',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final percent = double.parse(percentController.text);
                final seconds = double.parse(secondsController.text);
                if (seconds > 0 && percent >= 0) {
                  final rate = (percent / 100.0) / seconds;
                  Navigator.of(ctx).pop(rate);
                }
              } catch (e) {
                // Invalid input
              }
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      onApply(result);
    }
  }
}

/// Reusable widget for editing threshold values (0-100%) with a dialog.
class ThresholdInput extends StatelessWidget {
  final String label;
  final double currentThreshold;
  final ValueChanged<double> onApply;

  const ThresholdInput({
    super.key,
    required this.label,
    required this.currentThreshold,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final percentValue = (currentThreshold * 100).toStringAsFixed(0);
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                Text('$percentValue%', 
                  style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
              ),
              onPressed: () => _showThresholdEditDialog(context),
              child: const Text('EDIT', style: TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showThresholdEditDialog(BuildContext context) async {
    final percentController = TextEditingController(text: (currentThreshold * 100).toStringAsFixed(0));
    
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set threshold percentage (0-100%):', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 12),
            TextField(
              controller: percentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Percentage',
                suffixText: '%',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final percent = double.parse(percentController.text);
                if (percent >= 0 && percent <= 100) {
                  final threshold = (percent / 100.0).clamp(0.0, 1.0);
                  Navigator.of(ctx).pop(threshold);
                }
              } catch (e) {
                // Invalid input
              }
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      onApply(result);
    }
  }
}

/// Reusable widget for editing a simple float value with a dialog.
class FloatInput extends StatelessWidget {
  final String label;
  final String? subtitle;
  final double currentValue;
  final ValueChanged<double> onApply;
  final Color? backgroundColor;

  const FloatInput({
    super.key,
    required this.label,
    this.subtitle,
    required this.currentValue,
    required this.onApply,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ),
        Row(
          children: [
            Text(currentValue.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            SizedBox(
              height: 28,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor ?? Colors.blue.shade100,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                ),
                onPressed: () => _showFloatEditDialog(context),
                child: const Text('EDIT', style: TextStyle(fontSize: 9)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showFloatEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: currentValue.toString());
    
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final val = double.parse(controller.text);
                if (val >= 0) {
                  Navigator.of(ctx).pop(val);
                }
              } catch (e) {
                // Invalid input
              }
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      onApply(result);
    }
  }
}
