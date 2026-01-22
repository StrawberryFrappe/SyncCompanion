# Bio Signal Processing Handover: Fix False Positives & Freezing

## Current State
The `BioSignalProcessor` has been ported from the MAX30100 reference library (100Hz, Butterworth LPF, Beat State Machine).

## Issues Reported by User
1.  **Freezing on Finger Placement:** App "freezes" when finger is placed on sensor. 
    *   *Suspect:* The app uses measurements history to detect "human", but old/stale history from noise might be blocking fresh valid data interpretation.
    *   *Suggested Fix:* **Flush/Reset history** if the signal "freezes" or no beats are detected for X seconds (e.g., 5s).
2.  **False Positives:** Sensor points at pants/air and says "SIGNAL GOOD".
    *   *Suspect:* Random noise from fabric/light is passing the simplified "Raw IR > 5000" check and triggering the beat detector (which is sensitive).
    *   *Sugested Fix:* 
        *   Re-introduce a **Beat Stability Check** (variance check) but tuned less aggressively than before.
        *   Implement **DC Stability Check**: A moving finger or fabric causes massive DC swings; a stable finger has relatively stable DC.
        *   Analyze **AC Amplitude**: Noise might be too small or too large compared to a real pulse.

## Handover Task
1.  Analyze `bio_signal_processor.dart`.
2.  Implement a `_lastBeatTime` check: If `DateTime.now() - _lastBeatTime > 5s`, **flush all history queues** (`_bpmHistory`, `_spo2History`) and reset the beat detector state. This fixes the "sticking/freezing" on old data.
3.  Tackle False Positives:
    *   Check for AC Amplitude consistency.
    *   Maybe reject beats if the BPM variance is too wild (e.g. 60 -> 140 -> 50).
    *   Consider a "sustained valid signal" timer before showing "SIGNAL GOOD".
