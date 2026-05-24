import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

import '../../../app/theme.dart';
import '../../../core/device_location.dart';
import '../../../core/google_maps_config.dart';

const _addressPlaceTypes = {
  PlaceType.STREET_ADDRESS,
  PlaceType.ROUTE,
  PlaceType.PREMISE,
  PlaceType.SUBPREMISE,
  PlaceType.STREET_NUMBER,
  PlaceType.INTERSECTION,
};

final _houseNumberPattern = RegExp(r'\d+\s*[a-zA-Z]?', caseSensitive: false);

bool _queryHasHouseNumber(String query) => _houseNumberPattern.hasMatch(query);

bool _isAddressLike(AutocompletePrediction prediction, String query) {
  final types = prediction.placeTypes;
  if (types != null && types.isNotEmpty) {
    return types.any(_addressPlaceTypes.contains);
  }
  // Android plugin omits placeTypes — infer from text.
  return !_queryHasHouseNumber(prediction.primaryText) &&
      _matchesStreetQuery(query, prediction.primaryText);
}

/// Street/route result without a specific house number (Maps-style top suggestion).
bool _isStreetWithoutNumber(AutocompletePrediction prediction) {
  final types = prediction.placeTypes ?? const [];
  if (types.isEmpty) return false;
  if (types.contains(PlaceType.STREET_ADDRESS)) return false;
  if (types.contains(PlaceType.STREET_NUMBER)) return false;
  return types.contains(PlaceType.ROUTE);
}

bool _matchesStreetQuery(String query, String primaryText) {
  final q = query.toLowerCase().trim();
  final p = primaryText.toLowerCase().trim();
  if (q.isEmpty || p.isEmpty) return false;
  if (p.startsWith(q) || q.startsWith(p)) return true;
  final pStreet = p.split(',').first.trim();
  final qStreet = q.split(',').first.trim();
  return pStreet.startsWith(qStreet) || qStreet.startsWith(pStreet);
}

bool _looksLikeStreetWithoutNumber(AutocompletePrediction prediction, String query) {
  if (_queryHasHouseNumber(prediction.primaryText)) return false;
  if (_queryHasHouseNumber(prediction.fullText)) return false;
  final types = prediction.placeTypes;
  if (types != null && types.isNotEmpty) {
    return _isStreetWithoutNumber(prediction);
  }
  return _matchesStreetQuery(query, prediction.primaryText);
}

bool _shouldOfferAddStreetNumber(_AddressSuggestion suggestion, String query) {
  if (_queryHasHouseNumber(query)) return false;
  final prediction = suggestion.prediction;
  if (prediction == null) return false;
  return _looksLikeStreetWithoutNumber(prediction, query);
}

int _matchScore(String query, String text) {
  final q = query.toLowerCase().trim();
  final t = text.toLowerCase();
  if (t.contains(q)) return 1000;

  var score = 0;
  for (final part in q.split(RegExp(r'\s+'))) {
    if (part.length >= 2 && t.contains(part)) score += 40;
  }

  final number = _houseNumberPattern.stringMatch(q);
  if (number != null) {
    final normalized = number.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (t.replaceAll(RegExp(r'\s+'), '').contains(normalized)) score += 200;
  }

  return score;
}

List<AutocompletePrediction> _rankPredictions(List<AutocompletePrediction> items, String query) {
  final hasNumber = _queryHasHouseNumber(query);
  return [...items]..sort((a, b) {
      var scoreA = _matchScore(query, a.fullText) + (_isAddressLike(a, query) ? 5 : 0);
      var scoreB = _matchScore(query, b.fullText) + (_isAddressLike(b, query) ? 5 : 0);
      if (!hasNumber) {
        if (_looksLikeStreetWithoutNumber(a, query)) scoreA += 30;
        if (_looksLikeStreetWithoutNumber(b, query)) scoreB += 30;
      }
      return scoreB.compareTo(scoreA);
    });
}

/// One row in the autocomplete list — from autocomplete and/or text search.
class _AddressSuggestion {
  const _AddressSuggestion.prediction(this.prediction) : place = null;
  const _AddressSuggestion.place(this.place) : prediction = null;

  final AutocompletePrediction? prediction;
  final Place? place;

  bool isAddressLike(String query) =>
      prediction != null ? _isAddressLike(prediction!, query) : true;

  String get primaryText {
    if (prediction != null) return prediction!.primaryText;
    final address = place!.address?.trim();
    if (address != null && address.isNotEmpty) {
      return address.split(',').first.trim();
    }
    return place!.name?.trim() ?? '';
  }

  String get secondaryText {
    if (prediction != null) return prediction!.secondaryText;
    final address = place!.address?.trim();
    if (address == null || !address.contains(',')) return '';
    return address.substring(address.indexOf(',') + 1).trim();
  }

  String get line {
    if (prediction != null) return prediction!.fullText;
    return place!.address ?? place!.name ?? '';
  }

  /// Street name only — primary line before the first comma (Maps "add number" mode).
  String get streetName {
    final raw = primaryText.trim();
    if (raw.isEmpty) return raw;
    return raw.split(',').first.trim();
  }

  String get displaySecondary {
    if (secondaryText.isNotEmpty) return secondaryText;
    final raw = primaryText.trim();
    if (!raw.contains(',')) return '';
    return raw.substring(raw.indexOf(',') + 1).trim();
  }
}

/// Address field with Google Places autocomplete when [googleMapsApiKey] is set.
class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.decoration,
    this.textInputAction,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final TextInputAction? textInputAction;

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  FlutterGooglePlacesSdk? _places;
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<_AddressSuggestion> _predictions = [];
  bool _loading = false;
  bool _showSuggestions = false;
  String? _apiError;

  @override
  void initState() {
    super.initState();
    final apiKey = googleMapsApiKey;
    if (apiKey != null) {
      _places = FlutterGooglePlacesSdk(apiKey);
    }
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    if (apiKey != null) {
      unawaited(deviceLocationForPlaces());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() => _showSuggestions = false);
    }
  }

  void _onTextChanged() {
    if (!_focusNode.hasFocus) return;
    _debounce?.cancel();
    final query = widget.controller.text.trim();
    if (query.length < 2 || _places == null) {
      setState(() {
        _predictions = [];
        _showSuggestions = false;
        _loading = false;
        _apiError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetchPredictions(query));
  }

  String? _messageForError(Object error) {
    if (error is! PlatformException) return null;
    final message = error.message ?? '';
    if (message.contains('AutocompletePlaces are blocked') ||
        message.contains('9011')) {
      return 'Address suggestions unavailable. Enable Places API (New) for your Google Maps key.';
    }
    return null;
  }

  Future<List<_AddressSuggestion>> _querySuggestions(String query, LatLng? origin) async {
    // House numbers mean a specific address — skip GPS bias so distant job sites still match.
    final useLocation = origin != null && !_queryHasHouseNumber(query);
    final response = await _places!.findAutocompletePredictions(
      query,
      origin: useLocation ? origin : null,
      locationBias: useLocation ? locationBiasAround(origin) : null,
    );

    final ranked = _rankPredictions(response.predictions, query);
    final suggestions = ranked.map(_AddressSuggestion.prediction).toList();

    if (!_queryHasHouseNumber(query)) return suggestions;

    final textHits = await _textSearchAddresses(query, origin);
    return _mergeSuggestions(suggestions, textHits, query);
  }

  Future<List<Place>> _textSearchAddresses(String query, LatLng? origin) async {
    try {
      // Specific street numbers are often abroad — don't lock text search to locale/GPS.
      final response = await FlutterGooglePlacesSdk.platform.searchByText(
        query,
        fields: const [
          PlaceField.FormattedAddress,
          PlaceField.DisplayName,
          PlaceField.Id,
        ],
        regionCode: '',
        maxResultCount: 5,
      );
      return response.places;
    } catch (_) {
      return [];
    }
  }

  List<_AddressSuggestion> _mergeSuggestions(
    List<_AddressSuggestion> autocomplete,
    List<Place> textHits,
    String query,
  ) {
    final merged = <_AddressSuggestion>[];
    final seen = <String>{};

    void add(_AddressSuggestion item) {
      final key = item.line.toLowerCase();
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      merged.add(item);
    }

    for (final place in textHits) {
      final line = place.address ?? place.name ?? '';
      if (_matchScore(query, line) >= 40) {
        add(_AddressSuggestion.place(place));
      }
    }

    for (final item in autocomplete) {
      add(item);
    }

    merged.sort((a, b) => _matchScore(query, b.line).compareTo(_matchScore(query, a.line)));
    return merged;
  }

  Future<void> _fetchPredictions(String query) async {
    setState(() {
      _loading = true;
      _apiError = null;
    });
    try {
      final origin = await deviceLocationForPlaces();
      final predictions = await _querySuggestions(query, origin);
      if (!mounted) return;
      setState(() {
        _predictions = predictions;
        _showSuggestions = _focusNode.hasFocus && predictions.isNotEmpty;
        _loading = false;
        _apiError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _predictions = [];
        _showSuggestions = false;
        _loading = false;
        _apiError = _messageForError(e);
      });
    }
  }

  Future<void> _selectSuggestion(_AddressSuggestion suggestion) async {
    _debounce?.cancel();
    setState(() {
      _showSuggestions = false;
      _predictions = [];
      _loading = true;
    });
    _focusNode.unfocus();

    if (suggestion.prediction != null) {
      await _selectPrediction(suggestion.prediction!);
      return;
    }

    var address = suggestion.line;
    final place = suggestion.place!;
    if (place.id != null) {
      try {
        final details = await _places!.fetchPlace(
          place.id!,
          fields: const [PlaceField.FormattedAddress],
        );
        final formatted = details.place?.address;
        if (formatted != null && formatted.isNotEmpty) address = formatted;
      } catch (_) {}
    }

    widget.controller.text = address;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _selectPrediction(AutocompletePrediction prediction) async {
    var address = prediction.fullText;
    try {
      final details = await _places!.fetchPlace(
        prediction.placeId,
        fields: const [PlaceField.FormattedAddress],
      );
      final formatted = details.place?.address;
      if (formatted != null && formatted.isNotEmpty) {
        address = formatted;
      }
    } catch (_) {}

    widget.controller.text = address;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _beginAddStreetNumber(_AddressSuggestion suggestion) async {
    _debounce?.cancel();
    final street = suggestion.streetName;
    if (street.isEmpty) return;

    setState(() {
      _showSuggestions = false;
      _predictions = [];
    });

    final text = '$street ';
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _restoreFieldFocus();
  }

  void _restoreFieldFocus() {
    void restore() {
      if (!mounted) return;
      _focusNode.requestFocus();
      final len = widget.controller.text.length;
      widget.controller.selection = TextSelection.collapsed(offset: len);
    }

    restore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      restore();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  Widget _buildSuggestionRow(
    _AddressSuggestion suggestion, {
    required String query,
    required bool showAddStreetNumber,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: showAddStreetNumber
              ? () => _beginAddStreetNumber(suggestion)
              : () => _selectSuggestion(suggestion),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, showAddStreetNumber ? 4 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  suggestion.isAddressLike(query) ? Icons.home_outlined : Icons.place_outlined,
                  size: 20,
                  color: AppColors.subtle,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showAddStreetNumber ? suggestion.streetName : suggestion.primaryText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                      if (suggestion.displaySecondary.isNotEmpty)
                        Text(
                          suggestion.displaySecondary,
                          style: const TextStyle(fontSize: 12, color: AppColors.subtle),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showAddStreetNumber)
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 0, 14, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => _beginAddStreetNumber(suggestion),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: AppColors.accentDark),
                      const SizedBox(width: 4),
                      Text(
                        'Add street number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_places == null) {
      return TextFormField(
        controller: widget.controller,
        decoration: widget.decoration,
        textInputAction: widget.textInputAction,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: widget.decoration?.copyWith(
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.decoration?.suffixIcon,
          ),
          textInputAction: widget.textInputAction,
          onTap: () {
            if (widget.controller.text.trim().length >= 2) {
              _onTextChanged();
            }
          },
        ),
        if (_apiError != null) ...[
          const SizedBox(height: 6),
          Text(
            _apiError!,
            style: const TextStyle(fontSize: 12, color: AppColors.subtle),
          ),
        ],
        if (_showSuggestions) ...[
          const SizedBox(height: 4),
          TextFieldTapRegion(
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Builder(
                  builder: (context) {
                    final query = widget.controller.text.trim();
                    final canAddNumber = !_queryHasHouseNumber(query);
                    final addNumberIndex = canAddNumber
                        ? _predictions.indexWhere((s) => _shouldOfferAddStreetNumber(s, query))
                        : -1;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _predictions.length; i++)
                          _buildSuggestionRow(
                            _predictions[i],
                            query: query,
                            showAddStreetNumber: i == addNumberIndex,
                          ),
                      ],
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Image(
                      image: FlutterGooglePlacesSdk.ASSET_POWERED_BY_GOOGLE_ON_WHITE,
                      height: 14,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
