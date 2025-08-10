export function buildKey(parts) {
    return parts.filter(Boolean).join(':');
}
// Rate limit port + planned algorithms (sliding window / token bucket)
