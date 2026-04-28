import re

file_path = "android/app/src/main/kotlin/com/strawberryFrappe/sync_companion/BleForegroundService.kt"
with open(file_path, "r") as f:
    content = f.read()

content = content.replace("consecutiveValidSamples > 50", "consecutiveValidSamples > 15")
content = content.replace("bpmStdDev < 30.0", "bpmStdDev < 40.0")

with open(file_path, "w") as f:
    f.write(content)
