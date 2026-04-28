import re

file_path = "android/app/src/main/kotlin/com/strawberryFrappe/sync_companion/BleForegroundService.kt"
with open(file_path, "r") as f:
    content = f.read()

# Add lastHumanDetectedTimeMs
if "private var lastHumanDetectedTimeMs = 0L" not in content:
    content = content.replace("var humanDetected = false", "var humanDetected = false\n    private var lastHumanDetectedTimeMs = 0L\n")

# Replace newHumanDetected logic
old_logic = """        val newHumanDetected = fingerDetectedState && hasValidVitals && fingerSustained && isBpmStable
        
        if (newHumanDetected != humanDetected) {
            humanDetected = newHumanDetected
            updatePersistedStats()
        }"""

new_logic = """        val newHumanDetected = fingerDetectedState && hasValidVitals && fingerSustained && isBpmStable
        
        if (newHumanDetected) {
            lastHumanDetectedTimeMs = System.currentTimeMillis()
        }
        
        val effectivelyDetected = newHumanDetected || (System.currentTimeMillis() - lastHumanDetectedTimeMs < 15000L)
        if (effectivelyDetected != humanDetected) {
            humanDetected = effectivelyDetected
            updatePersistedStats()
        }"""

content = content.replace(old_logic, new_logic)

# Replace resetOnNoFinger logic
old_reset = """        if (humanDetected) {
            humanDetected = false
            updatePersistedStats()
        }"""

new_reset = """        val effectivelyDetected = (System.currentTimeMillis() - lastHumanDetectedTimeMs < 15000L)
        if (effectivelyDetected != humanDetected) {
            humanDetected = effectivelyDetected
            updatePersistedStats()
        }"""

content = content.replace(old_reset, new_reset)

with open(file_path, "w") as f:
    f.write(content)
