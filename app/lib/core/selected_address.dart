/// Picks the address string to store after a Places suggestion is selected.
///
/// Google Place Details often returns a less specific street line than the
/// autocomplete prediction (e.g. "Laugavegur 54" instead of "Laugavegur 54b").
String resolveSelectedAddress(String predictionText, String? formattedAddress) {
  final fallback = predictionText.trim();
  final formatted = formattedAddress?.trim();
  if (formatted == null || formatted.isEmpty) return fallback;

  final predictionStreet = _streetLine(fallback);
  final formattedStreet = _streetLine(formatted);
  if (predictionStreet.isEmpty || formattedStreet.isEmpty) return formatted;

  if (_streetLineIsMoreSpecific(predictionStreet, formattedStreet)) {
    return fallback;
  }

  return formatted;
}

String _streetLine(String address) => address.split(',').first.trim();

bool _streetLineIsMoreSpecific(String specific, String general) {
  final normalizedSpecific = specific.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final normalizedGeneral = general.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  if (normalizedSpecific == normalizedGeneral) return false;
  return normalizedSpecific.startsWith(normalizedGeneral) &&
      normalizedSpecific.length > normalizedGeneral.length;
}
