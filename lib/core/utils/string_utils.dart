//// Returns the first letter of [name] uppercased, or a fallback character
/// if the name is empty. Prevents crashes from empty/null names anywhere
/// an avatar initial is shown.
String getInitial(String? name, {String fallback = '?'}) {
  if (name == null || name.trim().isEmpty) return fallback;
  return name.trim()[0].toUpperCase();
}