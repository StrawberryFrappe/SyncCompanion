import re

file_path = "android/app/src/main/kotlin/com/strawberryFrappe/sync_companion/BleForegroundService.kt"
with open(file_path, "r") as f:
    content = f.read()

eval_code = """
    fun evaluateGracePeriod() {
        val effectivelyDetected = (System.currentTimeMillis() - lastHumanDetectedTimeMs < 15000L)
        if (humanDetected && !effectivelyDetected) {
            humanDetected = false
            updatePersistedStats()
        }
    }
"""

content = content.replace("    private fun resetOnNoFinger() {", eval_code + "\n    private fun resetOnNoFinger() {")

# In syncStateTimer:
old_timer = "                        if (bioProcessor.humanDetected) {"
new_timer = "                        bioProcessor.evaluateGracePeriod()\n                        if (bioProcessor.humanDetected) {"

content = content.replace(old_timer, new_timer)

with open(file_path, "w") as f:
    f.write(content)
