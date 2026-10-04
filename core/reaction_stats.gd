## Collects reaction times in milliseconds and summarises them.
class_name ReactionStats
extends RefCounted

var times_ms: Array[int] = []


func add(ms: int) -> void:
	times_ms.append(ms)


func count() -> int:
	return times_ms.size()


func mean() -> float:
	if times_ms.is_empty():
		return 0.0
	var sum := 0
	for t in times_ms:
		sum += t
	return float(sum) / times_ms.size()


func median() -> float:
	if times_ms.is_empty():
		return 0.0
	var sorted: Array[int] = times_ms.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return float(sorted[middle])
	return (sorted[middle - 1] + sorted[middle]) / 2.0


func best() -> int:
	return times_ms.min() if not times_ms.is_empty() else 0


func std_dev() -> float:
	if times_ms.size() < 2:
		return 0.0
	var avg := mean()
	var sum_sq := 0.0
	for t in times_ms:
		sum_sq += (t - avg) * (t - avg)
	return sqrt(sum_sq / times_ms.size())
