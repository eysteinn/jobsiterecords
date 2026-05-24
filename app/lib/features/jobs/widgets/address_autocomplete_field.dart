import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

import '../../../app/theme.dart';
import '../../../core/device_location.dart';
import '../../../core/google_maps_config.dart';

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
  List<AutocompletePrediction> _predictions = [];
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
      // Warm location cache so the first autocomplete request can rank nearby results.
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

  Future<void> _fetchPredictions(String query) async {
    setState(() {
      _loading = true;
      _apiError = null;
    });
    try {
      final origin = await deviceLocationForPlaces();
      final response = await _places!.findAutocompletePredictions(
        query,
        origin: origin,
        locationBias: origin != null ? locationBiasAround(origin) : null,
      );
      if (!mounted) return;
      setState(() {
        _predictions = response.predictions;
        _showSuggestions = _focusNode.hasFocus && response.predictions.isNotEmpty;
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

  Future<void> _selectPrediction(AutocompletePrediction prediction) async {
    _debounce?.cancel();
    setState(() {
      _showSuggestions = false;
      _predictions = [];
      _loading = true;
    });
    _focusNode.unfocus();

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
    } catch (_) {
      // Keep autocomplete line if details fetch fails.
    }

    widget.controller.text = address;
    if (mounted) setState(() => _loading = false);
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
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in _predictions)
                  InkWell(
                    onTap: () => _selectPrediction(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place_outlined, size: 20, color: AppColors.subtle),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.primaryText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.ink,
                                  ),
                                ),
                                if (p.secondaryText.isNotEmpty)
                                  Text(
                                    p.secondaryText,
                                    style: const TextStyle(fontSize: 12, color: AppColors.subtle),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
        ],
      ],
    );
  }
}
