//// Returns the first letter of [name] uppercased, or a fallback character
/// if the name is empty. Prevents crashes from empty/null names anywhere
/// an avatar initial is shown.
String getInitial(String? name, {String fallback = '?'}) {
  if (name == null || name.trim().isEmpty) return fallback;
  return name.trim()[0].toUpperCase();
}
/// Turns a Supabase Storage public URL back into the file's path inside
/// [bucket] (e.g. ".../object/public/avatars/abc/x.jpg?t=1" → "abc/x.jpg").
/// A value that is already a plain path is returned unchanged. Returns null
/// for an empty value or a URL from a different bucket.
String? storagePathFromUrl(String? value, String bucket) {
  if (value == null || value.isEmpty) return null;
  if (!value.startsWith('http')) return value;
  final marker = '/$bucket/';
  final i = value.indexOf(marker);
  if (i == -1) return null;
  return Uri.decodeComponent(value.substring(i + marker.length).split('?').first);
}
